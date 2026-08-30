// -----------------------------------------------------------------------------

import fs from 'fs';
import path from 'path';
import shell from 'shelljs';
import inquirer from 'inquirer';
import {spawn} from 'child_process';

// -----------------------------------------------------------------------------

import {colors, foxLogger, godotLogger} from '../logger.js';
import updatePreset from './update-preset.js';
import {writeOverride, resolveSteamAppId, ENV_CHOICES} from './switch.js';
import {readCurrentBundle, findPreset} from './resolve-env-preset.js';
import {readPresets, writePresets, PRESETS_CFG} from './read-presets.js';
import {tagVersion, readProjectVersion} from './tag.js';

// -----------------------------------------------------------------------------

const PROJECT_GODOT = 'project.godot';

const ALL = 'all';
const PLATFORMS = ['Linux', 'Windows Desktop', 'macOS'];
const PLATFORM_LABELS = {Linux: 'Linux-SteamOS'};

const BOLD = '\x1b[1m';
const RESET = '\x1b[0m';

// Bright foregrounds, no background: the chip has to stand out against the
// terminal's own theme, not fight it with a filled block.
const ENV_FOREGROUNDS = {
  debug: '\x1b[94m',
  demo: '\x1b[95m',
  staging: '\x1b[93m',
  release: '\x1b[92m'
};

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
// The bake below rewrites versioned files (project.godot, export_presets.cfg) for
// the duration of the export only, then reverts them with `git restore`. That
// revert is destructive by nature, so it is gated on a clean working tree: with
// nothing pending, there is nothing a restore can throw away. Untracked files are
// ignored — `git restore` never touches them.

const PATCHED_FILES = [PROJECT_GODOT, PRESETS_CFG];

const isGitRepo = () =>
  shell.exec('git rev-parse --is-inside-work-tree', {silent: true}).code === 0;

const verifyCleanTree = () => {
  const {stdout} = shell.exec('git status --porcelain --untracked-files=no', {silent: true});
  const pending = stdout.trim();

  if (!pending) {
    return true;
  }

  foxLogger.error('Working tree is not clean — commit or stash before exporting');
  foxLogger.error('fox bakes [bundle] + Steam app_id into project.godot, then restores it');
  pending.split('\n').forEach((line) => foxLogger.log(line));

  return false;
};

const restorePatchedFiles = () => {
  const files = PATCHED_FILES.filter((file) => fs.existsSync(file));
  shell.exec(`git restore -- ${files.join(' ')}`, {silent: true});
  godotLogger.log(`Restored ${files.join(', ')} (build bake reverted)`);
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
// The env decides which presets are exported, hence which folder gets filled.
// `fox publish` reads that folder and never this run, so an export left on the
// wrong env ships stale bytes under a fresh build number — with a build
// description carrying the CURRENT version, which makes the mismatch invisible
// on Steamworks. Both the banner and the env prompt exist to make the target
// folder impossible to miss before a single byte is written.

const exportRootForEnv = (presets, env) => {
  const preset = PLATFORMS.map((platform) => findPreset(presets, platform, env)).find(Boolean);

  if (!preset || !preset.export_path) {
    return null;
  }

  return path.dirname(path.dirname(preset.export_path));
};

// `prod` is what ENV_CHOICES calls the `release` env: the chip must speak the
// prompt's language, not the preset's.
const envLabel = (env) => {
  const choice = ENV_CHOICES.find(({value}) => value === env);
  return (choice ? choice.name : env).toUpperCase();
};

const envChip = (env) => {
  const foreground = ENV_FOREGROUNDS[env] || colors.white;
  return `${foreground}${BOLD}${envLabel(env)}${RESET}`;
};

// What already sits in a folder is what `fox publish` would ship if this run
// filled a different one. Reading it off disk is the only way to tell a fresh
// export from bytes left there weeks ago — the version in the banner describes
// the build about to be made, never the one already lying in the other envs.
const lastExportAt = (presets, env) => {
  const stamps = PLATFORMS.map((platform) => {
    const preset = findPreset(presets, platform, env);

    if (!preset || !preset.export_path) {
      return null;
    }

    try {
      return fs.statSync(path.resolve(process.cwd(), preset.export_path)).mtime;
    } catch (e) {
      return null;
    }
  }).filter(Boolean);

  if (!stamps.length) {
    return null;
  }

  return new Date(Math.max(...stamps.map((stamp) => stamp.getTime())));
};

const exportedLabel = (presets, env) => {
  const stamp = lastExportAt(presets, env);

  if (!stamp) {
    return `${colors.gray}(never exported)${colors.reset}`;
  }

  const local = new Date(stamp.getTime() - stamp.getTimezoneOffset() * 60000);
  return `${colors.gray}(last export ${local.toISOString().slice(0, 16).replace('T', ' ')})${colors.reset}`;
};

// Two lines on purpose: the identity of the build on one, the destination it is
// about to fill on the other, arrowed so it reads as a consequence.
const logBundleBanner = ({presets, title, bundleId, env, version, exportRoot}) => {
  const c = colors.cyan;
  const r = colors.reset;
  const target = exportRoot ? ` ${colors.gray}-> ${exportRoot}/${r}` : '';

  console.log(`${c}├─${r} ${c}●${r} ${BOLD}${title}${r} ${colors.gray}(${bundleId})${r} ${BOLD}v${version}${r}`);
  console.log(`${c}├────>${r}  ${envChip(env)}${target} ${exportedLabel(presets, env)}`);
};

// -----------------------------------------------------------------------------
// Keeping the current env is the default answer: a switch is always an explicit
// choice, never the consequence of hitting enter through the prompts.

const inquireEnv = async (presets, currentEnv) => {
  const others = ENV_CHOICES.filter(
    ({value}) => value !== currentEnv && exportRootForEnv(presets, value)
  );

  if (!others.length) {
    return currentEnv;
  }

  const {env} = await inquirer.prompt([
    {
      message: 'env',
      name: 'env',
      type: 'list',
      choices: [
        {
          name: `keep ${envChip(currentEnv)} (no switch) -> ${exportRootForEnv(presets, currentEnv)}/ ${exportedLabel(presets, currentEnv)}`,
          value: currentEnv
        },
        ...others.map(({value}) => ({
          name: `switch to ${envChip(value)} -> ${exportRootForEnv(presets, value)}/ ${exportedLabel(presets, value)}`,
          value
        }))
      ]
    }
  ]);

  return env;
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
        ...PLATFORMS.map((platform) => ({name: PLATFORM_LABELS[platform] || platform, value: platform}))
      ]
    }
  ]);

  return target === ALL ? PLATFORMS : [target];
};

// -----------------------------------------------------------------------------

// `forcedEnv` is how `fox publish` re-exports the env it is about to upload:
// the caller already knows the answer, so asking would only be a chance to get
// it wrong.
const exportBundle = async (settings, {forcedEnv} = {}) => {
  const {core: coreConfig, bundles} = settings;
  foxLogger.log('Exporting a bundle...');

  if (!bundles) {
    foxLogger.error('Missing bundles in fox.config.json');
    return;
  }

  // ---------

  verifyBuildFolder();

  // --------- versioned files are baked then restored: refuse a dirty tree

  const gitTracked = isGitRepo();

  if (gitTracked && !verifyCleanTree()) {
    return;
  }

  if (!gitTracked) {
    foxLogger.log('Not a git repository — project.godot will keep the baked values');
  }

  // ---------

  let presets = readPresets();
  if (!presets) {
    foxLogger.error('Failed during reading presets');
    return;
  }

  // --------- env comes from the last `fox switch`, and can be switched right here

  const current = readCurrentBundle();
  const currentEnv = current && current.env;
  const bundleId = (current && current.id) || Object.keys(bundles)[0];

  if (!currentEnv) {
    foxLogger.error('No current env in override.cfg — run `fox switch` first');
    return;
  }

  logBundleBanner({
    presets,
    title: getTitle(coreConfig),
    bundleId,
    env: currentEnv,
    version: readProjectVersion(),
    exportRoot: exportRootForEnv(presets, currentEnv)
  });

  const env = forcedEnv || (await inquireEnv(presets, currentEnv));

  if (env !== currentEnv) {
    foxLogger.warn(`switching env: ${currentEnv} -> ${env} (override.cfg is rewritten)`);
  }

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

  try {
    for (const platform of platforms) {
      const preset = findPreset(presets, platform, env);

      foxLogger.log(`--- ${platform} (${env}) -> ${preset.export_path} ---`);

      writeOverride(settings, {bundleId, platform, env});
      patchProjectGodotBundle({platform, env, steamAppId: resolveSteamAppId(settings, env)});

      const ok = await exportOnePreset(settings, presets, {bundleId, preset, env, newVersion});
      if (!ok) {
        foxLogger.error(`Aborting run: ${preset.name} failed`);
        return;
      }
    }
  } finally {
    if (gitTracked) {
      restorePatchedFiles();
    }
  }

  if (env !== currentEnv) {
    foxLogger.warn(`override.cfg now holds env=${env} — \`fox switch\` to go back to ${currentEnv}`);
  }

  foxLogger.done(
    `Exported ${platforms.length} platform(s) (${newVersion}) for env "${env}" -> ${exportRootForEnv(presets, env)}/`
  );

  return true;
};

// -----------------------------------------------------------------------------

export default exportBundle;
