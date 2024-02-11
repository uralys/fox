// -----------------------------------------------------------------------------

import chalk from 'chalk';
import fs from 'fs';
import path from 'path';
import inquirer from 'inquirer';
import shell from 'shelljs';
import {spawn} from 'child_process';

// -----------------------------------------------------------------------------

import updatePreset from './update-preset.js';
import switchBundle from './switch.js';
import {readPresets, writePresets} from './read-presets.js';
import { getNextVersion, increasePackageVersion, increasePresetsVersion } from './versioning.js';

// -----------------------------------------------------------------------------

const INCREASE_SEMVER_LEVELS = ['patch', 'minor', 'major'];

// -----------------------------------------------------------------------------

export const androidExtension = (env) => env === 'release' ? '.aab' : '.apk'

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
    console.log('✅ created _build folder');
  }
};

// -----------------------------------------------------------------------------

const unzipIPA = (bundleName) => {
  console.log(`\n⚙️  Unzipping ${bundleName}.app...`);

  const absolutePath = `${path.resolve(process.cwd())}/_build/iOS`
  shell.exec(`tar -xf ${absolutePath}/${bundleName}.ipa -C _build/iOS`)
  shell.rm('-rf', `${absolutePath}/${bundleName}.app`)
  shell.exec(`mv ${absolutePath}/Payload/${bundleName}.app ${absolutePath}/${bundleName}.app`)
  shell.rm('-rf', `${absolutePath}/Payload`)

  console.log(`\n${chalk.blue.bold(`_build/iOS/${bundleName}.app`)} is ready for ${chalk.bold('ios-deploy')}`);
  console.log(`ios-deploy --debug --bundle _build/iOS/${bundleName}.app`);
};

// -----------------------------------------------------------------------------

const exportBundle = async (settings) => {
  const {core: coreConfig, bundles} = settings;
  console.log(`⚙️  exporting a ${chalk.blue.bold('bundle')}...`);

  if (!bundles) {
    console.log('\nmissing bundles in fox.config.json');
    console.log(chalk.red.bold('🔴 failed'));
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
    console.log(chalk.red.bold('🔴 failed during reading presets.'));
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
    console.log(chalk.red.bold('🔴 failed during bundle settings preparation.'));
    return;
  }

  const {bundleId, preset, env} = bundleSettings;

  // ---------

  const bundleInfo = `${chalk.blue.bold(bundleId)} (${chalk.blue.bold(
    newVersion
  )}) for ${chalk.blue.bold(preset.name)}`;

  console.log(`\n⚙️  Ready to bundle ${bundleInfo}`);

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

  const exportType = `--export-${env}`;
  console.log(`\n⚙️  Exporting with ${exportType}...`);

  const bundler = spawn(coreConfig.godot, [exportType, preset.name, '--headless'], {
    stdio: [process.stdin, process.stdout, process.stderr]
  });

  bundler.on('close', () => {
    console.log(`\n${chalk.green.bold(applicationName)}`);
    console.log(`✅ Exported ${bundleInfo} successfully!`);

    if (preset.platform === 'iOS') {
      if(env === 'debug') {
        unzipIPA(bundleName);
      }

      console.log(`\n${chalk.blue.bold(`_build/iOS/${bundleName}.xcodeproj`)} is ready to be used with XCode`);
    }

    if (preset.platform === 'Android') {
      console.log(`\n${chalk.blue.bold(`_build/android/${bundleName}${androidExtension(env)}`)} is ready`);
      console.log(`adb install -r _build/android/${bundleName}${androidExtension(env)}`);
    }
  });
};

// -----------------------------------------------------------------------------

export default exportBundle;
