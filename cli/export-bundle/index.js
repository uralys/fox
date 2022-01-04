// -----------------------------------------------------------------------------

const chalk = require('chalk');
const fs = require('fs');
const inquirer = require('inquirer');
const shelljs = require('shelljs');

// -----------------------------------------------------------------------------

const ini = require('./ini');
const updatePreset = require('./update-preset');

// -----------------------------------------------------------------------------

const PRESETS_FILE = 'export_presets.cfg';

// -----------------------------------------------------------------------------

const inquireParams = async (bundles, _presets) => {
  const presets = _presets.preset;

  const questions = [
    {
      name: 'presetNum',
      type: 'list',
      choices: Object.keys(presets).map((num) => ({
        name: presets[num].name,
        value: num
      }))
    }
  ];

  const bundleIds = Object.keys(bundles);
  const singleBundleId = bundleIds.length > 1 ? null : bundleIds[0];

  if (!singleBundleId) {
    questions.push({
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

// -- great example for https://github.com/yargs/yargs/issues/1476
const exportBundle = async (coreConfig, bundles) => {
  console.log(`⚙️  exporting a ${chalk.blue.bold('bundle')}...`);

  if (!bundles) {
    console.log('\nmissing bundles in fox.config.json');
    console.log(chalk.red.bold('🔴 failed'));
    return;
  }

  const presets = ini.parse(fs.readFileSync(PRESETS_FILE, 'utf8'));
  const {bundleId, bundle, preset} = await inquireParams(bundles, presets);

  console.log(`⚙️  Ready to bundle ${bundleId} for ${preset.name}`);
  updatePreset(bundleId, coreConfig, preset, bundle);
  fs.writeFileSync(PRESETS_FILE, ini.stringify(presets));
};

// -----------------------------------------------------------------------------

module.exports = exportBundle;
