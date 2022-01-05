// -----------------------------------------------------------------------------

const chalk = require('chalk');
const fs = require('fs');
const inquirer = require('inquirer');
const shell = require('shelljs');
const {spawn} = require('child_process');

// -----------------------------------------------------------------------------

const ini = require('./ini');
const updatePreset = require('./update-preset');

// -----------------------------------------------------------------------------

const PRESETS_FILE = 'export_presets.cfg';
const SEMVER = ['patch', 'minor', 'major'];
const ENV = ['debug', 'production'];

// -----------------------------------------------------------------------------

const extractEnv = (preset) => {
  const _env = preset.custom_features.split(',').find((feature) => feature.includes('env:'));

  if (!_env) {
    console.warn(`\nmissing env in custom_features: "${preset.custom_features}"`);
    console.warn('add "env:debug" or "env:production" within the custom_features list');
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
  const packageJSON = JSON.parse(fs.readFileSync('./package.json', 'utf8'));

  const questions = [
    {
      message: 'version',
      name: 'versionLevel',
      type: 'list',
      choices: [`${packageJSON.version}`, ...SEMVER]
    },
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

  const bundleIds = Object.keys(bundles);
  const singleBundleId = bundleIds.length > 1 ? null : bundleIds[0];

  if (!singleBundleId) {
    questions.push({
      message: 'bundle',
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

  let presets;

  try {
    presets = ini.parse(fs.readFileSync(PRESETS_FILE, 'utf8'));
  } catch (e) {
    console.log(`\nCould not open ${PRESETS_FILE}`);
    console.log(chalk.red.bold('🔴 failed'));
    return;
  }

  const {bundleId, bundle, preset, versionLevel} = await inquireParams(bundles, presets);

  const env = extractEnv(preset);

  if (!env) {
    console.log(chalk.red.bold('🔴 failed'));
    return;
  }

  // ---------

  let newVersion = versionLevel;
  if (SEMVER.includes(versionLevel)) {
    console.log(`⚙️  npm version ${chalk.blue.bold(versionLevel)}`);
    const result = shell.exec(`npm version ${versionLevel}`);
    newVersion = /v(.+)\n/g.exec(result.stdout)[1];
  }

  const bundleInfo = `${chalk.blue.bold(bundleId)} (${chalk.blue.bold(
    newVersion
  )}) for ${chalk.blue.bold(preset.name)}`;

  // ---------

  console.log(`\n⚙️  Ready to bundle ${bundleInfo}`);

  updatePreset(bundleId, env, coreConfig, preset, bundle, newVersion);
  fs.writeFileSync(PRESETS_FILE, ini.stringify(presets));

  // ---------

  console.log('\n⚙️  Exporting...');

  const bundler = spawn(
    coreConfig.godot,
    [`--export${env === 'debug' ? '-debug' : ''}`, preset.name, '--no-window'],
    {stdio: [process.stdin, process.stdout, process.stderr]}
  );

  bundler.on('close', () => {
    console.log(`\n✅ Exported your ${bundleInfo} successfully!`);

    if (preset.platform === 'iOS') {
      console.log(
        `\n${chalk.yellow(
          'Note for iOS:'
        )} Exporting for iOS may fail on the archive creation, but it's not on the Godot part`
      );
      console.log(
        `The ${chalk.blue.bold(
          '.xcodeproj'
        )} has been properly exported, use it with XCode to fix errors.`
      );
    }
  });
};

// -----------------------------------------------------------------------------

module.exports = exportBundle;
