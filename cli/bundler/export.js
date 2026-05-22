// -----------------------------------------------------------------------------

import fs from 'fs';
import path from 'path';
import shell from 'shelljs';
import {spawn} from 'child_process';

// -----------------------------------------------------------------------------

import {foxLogger, godotLogger} from '../logger.js';
import updatePreset from './update-preset.js';
import switchBundle from './switch.js';
import {readPresets, writePresets} from './read-presets.js';
import {tagVersion, readProjectVersion} from './tag.js';

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
  const {bundleId, preset, env} = bundleSettings;

  let newVersion;

  if (env === 'release') {
    newVersion = await tagVersion();

    if (!newVersion) {
      foxLogger.error('Failed during versioning');
      return false;
    }
  } else {
    newVersion = readProjectVersion();
    foxLogger.log(`env=${env} — skipping version bump (using ${newVersion})`);
  }

  // ---------

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

  const exportType = `--export-${env === 'release' ? 'release' : 'debug'}`;
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

  const presets = readPresets();
  if (!presets) {
    foxLogger.error('Failed during reading presets');
    return;
  }

  // ---------

  const initial = await switchBundle(settings, presets);
  if (!initial) {
    foxLogger.error('Failed during bundle settings preparation');
    return;
  }

  // ---------

  if (initial.all) {
    foxLogger.log(`Building all ${Object.keys(presets).length} presets for bundle "${initial.bundleId}"`);

    for (const presetNum of Object.keys(presets)) {
      const preset = presets[presetNum];
      foxLogger.log(`--- ${preset.name} ---`);

      const bundleSettings = await switchBundle(settings, presets, {
        bundleId: initial.bundleId,
        preset
      });

      if (!bundleSettings) {
        foxLogger.warn(`Skipping ${preset.name} (invalid bundle settings)`);
        continue;
      }

      const ok = await exportOnePreset(settings, presets, bundleSettings);
      if (!ok) {
        foxLogger.error(`Aborting "all" run: ${preset.name} failed`);
        return;
      }
    }

    foxLogger.done(`All ${Object.keys(presets).length} presets exported`);
    return;
  }

  // ---------

  await exportOnePreset(settings, presets, initial);
};

// -----------------------------------------------------------------------------

export default exportBundle;
