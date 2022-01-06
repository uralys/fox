// -----------------------------------------------------------------------------

const chalk = require('chalk');
const fs = require('fs');
const inquirer = require('inquirer');
const shell = require('shelljs');

// -----------------------------------------------------------------------------

const ini = require('./ini');

// -----------------------------------------------------------------------------

const PRESETS_CFG = 'export_presets.cfg';
const OVERRIDE_CFG = 'override.cfg';

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

const switchBundle = async (bundles) => {
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

  let override;

  try {
    override = ini.parse(fs.readFileSync(OVERRIDE_CFG, 'utf8'));
    if (!override.bundle) override.bundle = {};
  } catch (e) {
    shell.touch(OVERRIDE_CFG);
    override = {bundle: {}};
    console.log(`\nCould not open ${OVERRIDE_CFG}. Created the file.`);
  }

  override.bundle.id = bundleId;
  override.bundle.platform = preset.platform;

  fs.writeFileSync(OVERRIDE_CFG, ini.stringify(override));

  return {bundleId, preset, presets};
};

// -----------------------------------------------------------------------------

module.exports = switchBundle;
