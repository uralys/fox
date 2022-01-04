// -----------------------------------------------------------------------------

const chalk = require('chalk');
const ini = require('ini');
const fs = require('fs');
const inquirer = require('inquirer');
const shelljs = require('shelljs');

// -----------------------------------------------------------------------------

const inquireParams = async (bundles, presets) => {
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

  return {bundleId, preset};
};

// -----------------------------------------------------------------------------

const updatePreset = (bundles, bundleId, preset) => {};

// -----------------------------------------------------------------------------

// -- great example for https://github.com/yargs/yargs/issues/1476
const exportBundle = async (bundles) => {
  console.log(`⚙️  exporting a ${chalk.blue.bold('bundle')}...`);

  if (!bundles) {
    console.log('\nmissing bundles in fox.config.json');
    console.log(chalk.red.bold('🔴 failed'));
    return;
  }

  const presets = ini.parse(fs.readFileSync('export_presets.cfg', 'utf-8')).preset;
  const {bundleId, preset} = await inquireParams(bundles, presets);

  updatePreset(bundles, presets, bundleId, preset);

  console.log(`Bundling ${bundleId} for ${preset.name}`);
};

// -----------------------------------------------------------------------------

module.exports = exportBundle;
