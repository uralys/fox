// -----------------------------------------------------------------------------

import chalk from 'chalk';
import fs from 'fs';
import inquirer from 'inquirer';
import shell from 'shelljs';

// -----------------------------------------------------------------------------

import ini from './ini.js';
import toVersionNumber from './version-number.js';

// -----------------------------------------------------------------------------

const PRESETS_CFG = 'export_presets.cfg';
const OVERRIDE_CFG = 'override.cfg';
const ENV = ['debug', 'production', 'pck'];

// -----------------------------------------------------------------------------

const extractEnv = (preset) => {
  const _env = preset.custom_features.split(',').find((feature) => feature.includes('env:'));

  if (!_env) {
    console.warn(`\nmissing env in custom_features: "${preset.custom_features}"`);
    console.warn('add "env:debug", "env:production" or "env:pck" within the custom_features list');
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

const inquireParams = async (bundles, _presets) => {
  const presets = _presets.preset;
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

const switchBundle = async (bundleVersion, bundles) => {
  console.log(`⚙️  switching to another ${chalk.blue.bold('bundle')}...`);

  if (!bundles) {
    console.log('\nmissing bundles in fox.config.json');
    console.log(chalk.red.bold('🔴 failed'));
    return;
  }

  let presets;

  try {
    presets = ini.parse(fs.readFileSync(PRESETS_CFG, 'utf8'));
  } catch (e) {
    console.log(`\nCould not open ${PRESETS_CFG}`);
    console.log(chalk.red.bold('🔴 failed'));
    return;
  }

  const {bundleId, preset} = await inquireParams(bundles, presets);

  // ---------

  const env = extractEnv(preset);

  if (!env) {
    console.log(chalk.red.bold('🔴 failed'));
    return;
  }

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

  override.fox.version = require('../../package.json').version;
  override.bundle.id = bundleId;
  override.bundle.version = bundleVersion;
  override.bundle.versionCode = toVersionNumber(bundleVersion);
  override.bundle.platform = preset.platform;
  override.bundle.env = env;

  fs.writeFileSync(OVERRIDE_CFG, ini.stringify(override));

  return {bundleId, preset, presets, env};
};

// -----------------------------------------------------------------------------

export default switchBundle;
