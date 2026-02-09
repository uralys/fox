// -----------------------------------------------------------------------------

import fs from 'fs';
import path from 'path';
import inquirer from 'inquirer';
import shell from 'shelljs';
import {spawn} from 'child_process';

// -----------------------------------------------------------------------------

import {foxLogger, godotLogger} from '../logger.js';
import updatePreset from './update-preset.js';
import switchBundle from './switch.js';
import {readPresets, writePresets} from './read-presets.js';
import { getNextVersion, increasePackageVersion, increasePresetsVersion } from './versioning.js';

// -----------------------------------------------------------------------------

const INCREASE_SEMVER_LEVELS = ['patch', 'minor', 'major'];

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

const inquireVersioning = async (currentVersion) => {
  const questions = [
    {
      message: 'version',
      name: 'versionLevel',
      type: 'list',
      choices: [`${currentVersion}`, ...INCREASE_SEMVER_LEVELS]
    }
  ];

  const answers = await inquirer.prompt(questions);
  const {versionLevel} = answers;
  return {versionLevel};
};

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

const exportBundle = async (settings) => {
  const {core: coreConfig, bundles} = settings;
  foxLogger.log('Exporting a bundle...');

  if (!bundles) {
    foxLogger.error('Missing bundles in fox.config.json');
    return;
  }

  // ---------

  verifyBuildFolder();

  // ---------

  const packageJSON = JSON.parse(fs.readFileSync('./package.json', 'utf8'));
  const currentVersion = packageJSON.version;

  // ---------

  const presets = readPresets();
  if (!presets) {
    foxLogger.error('Failed during reading presets');
    return;
  }

  // ---------

  const {versionLevel} = await inquireVersioning(currentVersion);
  const upgrading = versionLevel !== currentVersion;

  let newVersion = currentVersion

  if(upgrading) {
    newVersion = getNextVersion(currentVersion, versionLevel)
    increasePresetsVersion(newVersion, presets)
    increasePackageVersion(newVersion, versionLevel)
  }

  // ---------

  const bundleSettings = await switchBundle(settings, presets);
  if (!bundleSettings) {
    foxLogger.error('Failed during bundle settings preparation');
    return;
  }

  const {bundleId, preset, env} = bundleSettings;

  // ---------

  foxLogger.step(0, `Ready to bundle ${bundleId} (${newVersion}) for ${preset.name}`);

  const {applicationName, bundleName} = updatePreset(
    bundleId,
    env,
    coreConfig,
    preset,
    bundles[bundleId],
    newVersion
  );

  writePresets(presets);

  // ---------

  const exportType = `--export-${env === 'release' ? 'release' : 'debug'}`;
  godotLogger.log(`Exporting with ${exportType}...`);

  const bundler = spawn(coreConfig.godot, [exportType, preset.name, '--headless'], {
    stdio: [process.stdin, process.stdout, process.stderr]
  });

  bundler.on('close', () => {
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
  });
};

// -----------------------------------------------------------------------------

export default exportBundle;
