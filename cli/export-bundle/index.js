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
const SEMVER = ['patch', 'minor', 'major'];

// -----------------------------------------------------------------------------

const inquireParams = async (bundles, _presets) => {
  const presets = _presets.preset;
  const packageJSON = JSON.parse(fs.readFileSync('./package.json', 'utf8'));

  const questions = [
    {
      name: 'versionLevel',
      type: 'list',
      choices: [`${packageJSON.version}`, ...SEMVER]
    },
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
  const {bundleId = singleBundleId, presetNum, versionLevel} = answers;
  const preset = presets[presetNum];
  const bundle = bundles[bundleId];

  return {bundleId, bundle, preset, versionLevel};
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
  const {bundleId, bundle, preset, versionLevel} = await inquireParams(bundles, presets);

  let newVersion = versionLevel;
  if (SEMVER.includes(versionLevel)) {
    console.log(`⚙️  npm version ${chalk.blue.bold(versionLevel)}`);
    const result = shelljs.exec(`npm version ${versionLevel}`);
    newVersion = /v(.+)\n/g.exec(result.stdout)[1];
  }

  console.log(`⚙️  Ready to bundle ${bundleId} (${newVersion}) for ${preset.name}`);

  updatePreset(bundleId, coreConfig, preset, bundle, newVersion);
  fs.writeFileSync(PRESETS_FILE, ini.stringify(presets));
};

// -----------------------------------------------------------------------------

module.exports = exportBundle;
