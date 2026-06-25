// -----------------------------------------------------------------------------

import fs from 'fs';
import path from 'path';
import shell from 'shelljs';
import inquirer from 'inquirer';
import {spawn} from 'child_process';

// -----------------------------------------------------------------------------

import {foxLogger, godotLogger} from '../logger.js';
import updatePreset from './update-preset.js';
import {writeOverride, resolveSteamAppId} from './switch.js';
import {readCurrentBundle, findPreset} from './resolve-env-preset.js';
import {readPresets, writePresets} from './read-presets.js';
import {tagVersion, readProjectVersion} from './tag.js';

// -----------------------------------------------------------------------------

const PROJECT_GODOT = 'project.godot';

const ALL = 'all';
const PLATFORMS = ['Linux', 'Windows Desktop', 'macOS'];

// -----------------------------------------------------------------------------

export const androidExtension = (env) => env === 'release' ? '.aab' : '.apk'

export const getApplicationName = (coreConfig, bundle) => {
  const {title} = coreConfig;
  const {subtitle} = bundle;
  return subtitle ? `${title}: ${subtitle}` : title;
}

export const getTitle = (coreConfig) => coreConfig.title;
export const getSubtitle = (bundle) => {
  const {subtitle} = bundle;
  return subtitle;
}

// -----------------------------------------------------------------------------

const verifyBuildFolder = () => {
  const buildFolder = path.resolve(process.cwd(), './_build');

  if (!fs.existsSync(buildFolder)) {
    shell.mkdir('-p', buildFolder);
    foxLogger.success('Created _build folder');
  }
};

// -----------------------------------------------------------------------------
// Exported builds read `bundle/env` from the project.binary baked into the PCK.
// Godot serializes the in-memory ProjectSettings at export, so we keep both the
// editor source (override.cfg) and the PCK source (project.godot [bundle]) in
// sync for the target platform right before invoking the exporter.
//
// `override.cfg` does NOT reach the PCK (Godot ignores it in editor/headless and
// fox does not ship it next to the binary), so the per-env Steam app_id must be
// baked into project.godot too — otherwise GodotSteam's steamInitEx() reads the
// committed `initialization/app_id=0`. Verified by extracting project.binary from
// the demo PCK: it carried app_id=0 despite override.cfg holding 4873710.

const patchProjectGodotBundle = ({platform, env, steamAppId}) => {
  let content = fs.readFileSync(PROJECT_GODOT, 'utf8');

  content = content.replace(/^platform=".*"$/m, `platform="${platform}"`);
  content = content.replace(/^env=".*"$/m, `env="${env}"`);

  if (steamAppId) {
    content = content.replace(
      /^initialization\/app_id=.*$/m,
      `initialization/app_id=${steamAppId}`
    );
  }

  fs.writeFileSync(PROJECT_GODOT, content);

  const steamLog = steamAppId ? ` [steam] app_id=${steamAppId}` : '';
  godotLogger.log(`project.godot [bundle] -> platform="${platform}" env="${env}"${steamLog}`);
};

// -----------------------------------------------------------------------------

const unzipIPA = (bundleName) => {
  foxLogger.log(`Unzipping ${bundleName}.app...`);

  const absolutePath = `${path.resolve(process.cwd())}/_build/iOS`
  shell.exec(`tar -xf ${absolutePath}/${bundleName}.ipa -C _build/iOS`)
  shell.rm('-rf', `${absolutePath}/${bundleName}.app`)
  shell.exec(`mv ${absolutePath}/Payload/${bundleName}.app ${absolutePath}/${bundleName}.app`)
  shell.rm('-rf', `${absolutePath}/Payload`)

  foxLogger.success(`_build/iOS/${bundleName}.app is ready for your device`);
  foxLogger.log(`xcrun devicectl device install app _build/iOS/${bundleName}.app --device XXX`);
};

// -----------------------------------------------------------------------------

const exportOnePreset = async (settings, presets, bundleSettings) => {
  const {core: coreConfig, bundles} = settings;
  const {bundleId, preset, env, newVersion} = bundleSettings;

  foxLogger.step(0, `Ready to bundle ${bundleId} (${newVersion}) for ${preset.name}`);

  const {bundleName} = updatePreset(
    bundleId,
    env,
    coreConfig,
    preset,
    bundles[bundleId],
    newVersion
  );

  writePresets(presets);

  // ---------

  if (preset.export_path) {
    const exportDir = path.dirname(path.resolve(process.cwd(), preset.export_path));
    if (!fs.existsSync(exportDir)) {
      shell.mkdir('-p', exportDir);
      godotLogger.success(`Created ${exportDir}`);
    }
  }

  const exportType = `--export-${env === 'release' || env === 'demo' ? 'release' : 'debug'}`;
  godotLogger.log(`Exporting with ${exportType}...`);

  return new Promise((resolve) => {
    const bundler = spawn(coreConfig.godot, [exportType, preset.name, '--headless'], {
      stdio: [process.stdin, process.stdout, process.stderr]
    });

    bundler.on('close', (code) => {
      if (code !== 0) {
        godotLogger.error(`Export failed for ${preset.name} (exit ${code})`);
        resolve(false);
        return;
      }

      godotLogger.success('Build complete');

      if (preset.platform === 'iOS') {
        if(env === 'debug' || env === 'staging') {
          unzipIPA(bundleName);
        }
        foxLogger.log(`_build/iOS/${bundleName}.xcodeproj is ready to be used with XCode`);
      }

      if (preset.platform === 'Android') {
        foxLogger.log(`_build/android/${bundleName}${androidExtension(env)} is ready`);
        foxLogger.log(`adb install -r _build/android/${bundleName}${androidExtension(env)}`);
      }

      foxLogger.done(`Exported ${bundleId} (${newVersion}) for ${preset.name} ${env}`);
      resolve(true);
    });
  });
};

// -----------------------------------------------------------------------------

const inquirePlatforms = async () => {
  const {target} = await inquirer.prompt([
    {
      message: 'platform',
      name: 'target',
      type: 'list',
      choices: [
        {name: '✨ all', value: ALL},
        ...PLATFORMS.map((platform) => ({name: platform, value: platform}))
      ]
    }
  ]);

  return target === ALL ? PLATFORMS : [target];
};

// -----------------------------------------------------------------------------

const exportBundle = async (settings) => {
  const {bundles} = settings;
  foxLogger.log('Exporting a bundle...');

  if (!bundles) {
    foxLogger.error('Missing bundles in fox.config.json');
    return;
  }

  // ---------

  verifyBuildFolder();

  // ---------

  let presets = readPresets();
  if (!presets) {
    foxLogger.error('Failed during reading presets');
    return;
  }

  // --------- env comes from the last `fox switch`

  const current = readCurrentBundle();
  const env = current && current.env;
  const bundleId = (current && current.id) || Object.keys(bundles)[0];

  if (!env) {
    foxLogger.error('No current env in override.cfg — run `fox switch` first');
    return;
  }

  foxLogger.log(`Current env: ${env} (bundle "${bundleId}")`);

  // ---------

  const platforms = await inquirePlatforms();

  // --------- every target must resolve to a preset before any versioning

  for (const platform of platforms) {
    if (!findPreset(presets, platform, env)) {
      foxLogger.error(`No preset with env:${env} for platform "${platform}"`);
      foxLogger.error('Aborting: add the matching preset in export_presets.cfg');
      return;
    }
  }

  // --------- version resolved once: a single tag even when building `all`

  let newVersion;

  if (env === 'release') {
    newVersion = await tagVersion();
    if (!newVersion) {
      foxLogger.error('Failed during versioning');
      return;
    }
    presets = readPresets();
  } else {
    newVersion = readProjectVersion();
    foxLogger.log(`env=${env} — skipping version bump (using ${newVersion})`);
  }

  // ---------

  for (const platform of platforms) {
    foxLogger.log(`--- ${platform} (${env}) ---`);

    const preset = findPreset(presets, platform, env);

    writeOverride(settings, {bundleId, platform, env});
    patchProjectGodotBundle({platform, env, steamAppId: resolveSteamAppId(settings, env)});

    const ok = await exportOnePreset(settings, presets, {bundleId, preset, env, newVersion});
    if (!ok) {
      foxLogger.error(`Aborting run: ${preset.name} failed`);
      return;
    }
  }

  foxLogger.done(`Exported ${platforms.length} platform(s) (${newVersion}) for env "${env}"`);
};

// -----------------------------------------------------------------------------

export default exportBundle;
