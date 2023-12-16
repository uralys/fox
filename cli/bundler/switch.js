// -----------------------------------------------------------------------------

import chalk from 'chalk';
import fs from 'fs';
import inquirer from 'inquirer';
import shell from 'shelljs';

// -----------------------------------------------------------------------------

import ini from './ini.js';
import { toVersionNumber } from './versioning.js';

// -----------------------------------------------------------------------------

const OVERRIDE_CFG = './override.cfg';
const ENV = ['debug', 'release', 'pack'];

// -----------------------------------------------------------------------------

const extractEnv = (preset) => {
  const _env = preset.custom_features.split(',').find((feature) => feature.includes('env:'));

  if (!_env) {
    console.warn(`\n🔴 env:${chalk.red('export_presets.cfg must be edited')}`);
    console.warn(`Missing 'env' in custom_features: "${preset.custom_features}"`);
    console.warn(`add "env:debug", "env:release" or "env:pack" within the ${chalk.blueBright('custom_features')} list`);
    return;
  }

  const env = _env.split('env:')[1];

  if (!ENV.includes(env)) {
    console.warn(`env:${chalk.yellow(env)} is not supported, use one of [${ENV}]`);
    return;
  }

  return env;
};

// -----------------------------------------------------------------------------

const inquireParams = async (bundles, presets) => {
  const bundleIds = Object.keys(bundles);
  const singleBundleId = bundleIds.length > 1 ? null : bundleIds[0];

  const questions = [
    {
      message: 'preset',
      name: 'presetNum',
      type: 'list',
      choices: Object.keys(presets).map((num) => ({
        name: presets[num].name,
        value: num
      }))
    }
  ];

  if (!singleBundleId) {
    questions.push({
      message: 'bundle',
      name: 'bundleId',
      type: 'list',
      choices: bundleIds
    });
  }

  const answers = await inquirer.prompt(questions);
  const {bundleId = singleBundleId, presetNum} = answers;
  const preset = presets[presetNum];
  const bundle = bundles[bundleId];

  return {bundleId, bundle, preset};
};

// -----------------------------------------------------------------------------

const switchBundle = async (bundles, presets) => {
  console.log(`⚙️  switching to another ${chalk.blue.bold('bundle')}...`);

  if (!bundles) {
    console.log('\nmissing bundles in fox.config.json');
    console.log(chalk.red.bold('🔴 failed: you can use default config for bundles'));
    return;
  }

  if (!presets) {
    console.log(chalk.red.bold('🔴 failed: missing presets'));
    return;
  }

  const {bundleId, preset} = await inquireParams(bundles, presets);

  // ---------

  const env = extractEnv(preset);

  if (!env) {
    console.log(chalk.red.bold('🔴 failed: could not find env'));
    return;
  }

  console.log(`⚙️  env: ${env}`);

  // ---------

  let override;

  try {
    override = ini.parse(fs.readFileSync(OVERRIDE_CFG, 'utf8'));
    if (!override.bundle) override.bundle = {};
    if (!override.fox) override.fox = {};
  } catch (e) {
    shell.touch(OVERRIDE_CFG);
    override = {bundle: {}, fox: {}};
    console.log(`\nCould not open ${OVERRIDE_CFG}. Created the file.`);
  }

  const appPackageJSON = JSON.parse(fs.readFileSync('./package.json', 'utf8'));
  const foxPackageJSON = JSON.parse(fs.readFileSync('../fox/package.json', 'utf8'));

  override.fox.version = foxPackageJSON.version;
  override.bundle.id = bundleId;
  override.bundle.version = appPackageJSON.version;
  override.bundle.versionCode = toVersionNumber(appPackageJSON.version);
  override.bundle.platform = preset.platform;
  override.bundle.env = env;

  fs.writeFileSync(OVERRIDE_CFG, ini.stringify(override));

  return {bundleId, preset, env};
};

// -----------------------------------------------------------------------------

export default switchBundle;
