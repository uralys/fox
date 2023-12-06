// -----------------------------------------------------------------------------

import chalk from 'chalk';
import fs from 'fs';
import path from 'path';
import inquirer from 'inquirer';
import shell from 'shelljs';
import {spawn} from 'child_process';

// -----------------------------------------------------------------------------

import ini from './ini.js';
import updatePreset from './update-preset.js';
import switchBundle from './switch.js';

// -----------------------------------------------------------------------------

const PRESETS_CFG = 'export_presets.cfg';
const SEMVER = ['patch', 'minor', 'major'];

// -----------------------------------------------------------------------------

const inquireVersioning = async (currentVersion) => {
  const questions = [
    {
      message: 'version',
      name: 'versionLevel',
      type: 'list',
      choices: [`${currentVersion}`, ...SEMVER]
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
  shell.exec(`mv ${absolutePath}/Payload/${bundleName}.app ${absolutePath}/${bundleName}.app`)
  shell.rm('-rf', `${absolutePath}/Payload`)

  console.log(`\n${chalk.blue.bold(`_build/iOS/${bundleName}.app`)} is ready for ${chalk.bold('ios-deploy')}`);
  console.log(`ios-deploy --debug --bundle _build/iOS/${bundleName}.app`);
};

// -----------------------------------------------------------------------------

const exportBundle = async (coreConfig, bundles) => {
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

  const {versionLevel} = await inquireVersioning(currentVersion);

  let newVersion = versionLevel;
  if (SEMVER.includes(versionLevel)) {
    console.log(`⚙️  npm version ${chalk.blue.bold(versionLevel)}`);
    const result = shell.exec(`npm version ${versionLevel}`);

    try {
      newVersion = /v(.+)\n/g.exec(result.stdout)[1];
    } catch (e) {
      console.log(chalk.red.bold('🔴 failed during versioning, check "git status"'));
      return;
    }
  }

  // ---------

  const bundleSettings = await switchBundle(newVersion, bundles);
  if (!bundleSettings) {
    console.log(chalk.red.bold('🔴 failed during bundle settings preparation.'));
    return;
  }

  const {bundleId, preset, presets, env} = bundleSettings;

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

  fs.writeFileSync(PRESETS_CFG, ini.stringify(presets));

  // ---------

  console.log('\n⚙️  Exporting...');

  let exportType = '--export';
  if (env === 'debug') {
    exportType += '-debug';
  }
  if (env === 'pck') {
    exportType += '-pack';
  }

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
      console.log(`\n${chalk.blue.bold(`_build/android/${bundleName}.apk`)} is ready`);
      console.log(`adb -d install -r _build/android/${bundleName}.apk`);
    }
  });
};

// -----------------------------------------------------------------------------

export default exportBundle;
