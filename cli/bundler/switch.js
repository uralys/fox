// -----------------------------------------------------------------------------

import fs from 'fs';
import inquirer from 'inquirer';

// -----------------------------------------------------------------------------

import {switchLogger} from '../logger.js';
import ini from './ini.js';
import {toVersionNumber} from './versioning.js';
import {readProjectVersion} from './tag.js';
import {getSubtitle, getTitle} from './export.js';

// -----------------------------------------------------------------------------

const OVERRIDE_CFG = './override.cfg';
const ENV = ['debug', 'staging', 'release', 'demo'];

// -----------------------------------------------------------------------------

const extractEnv = (preset) => {
  const _env = preset.custom_features.split(',').find((feature) => feature.includes('env:'));

  if (!_env) {
    switchLogger.error('export_presets.cfg must be edited');
    switchLogger.warn(`Missing 'env' in custom_features: "${preset.custom_features}"`);
    switchLogger.warn(`Add one of [${ENV.map((e) => `env:${e}`).join(', ')}] within the custom_features list`);
    return;
  }

  const env = _env.split('env:')[1];

  if (!ENV.includes(env)) {
    switchLogger.warn(`env:${env} is not supported, use one of [${ENV}]`);
    return;
  }

  return env;
};

// -----------------------------------------------------------------------------

const ALL = 'all';

const inquireParams = async (bundles, presets) => {
  const bundleIds = Object.keys(bundles);
  const singleBundleId = bundleIds.length > 1 ? null : bundleIds[0];

  const presetChoices = Object.keys(presets).map((num) => ({
    name: presets[num].name,
    value: num
  }));

  const questions = [
    {
      message: 'preset',
      name: 'presetNum',
      type: 'list',
      choices: [
        { name: '✨ all', value: ALL },
        ...presetChoices
      ]
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
  const { bundleId = singleBundleId, presetNum } = answers;
  const bundle = bundles[bundleId];

  if (presetNum === ALL) {
    return { bundleId, bundle, all: true };
  }

  const preset = presets[presetNum];
  return { bundleId, bundle, preset };
};

// -----------------------------------------------------------------------------

const switchBundle = async (settings, presets, forced = null) => {
  const { core, bundles } = settings;
  switchLogger.log('Selecting bundle...');

  if (!bundles) {
    switchLogger.error('Missing bundles in fox.config.json');
    return;
  }

  if (!presets) {
    switchLogger.error('Missing presets');
    return;
  }

  let bundleId;
  let preset;

  if (forced) {
    bundleId = forced.bundleId;
    preset = forced.preset;
    switchLogger.log(`Using forced selection: ${preset.name} / ${bundleId}`);
  } else {
    const answers = await inquireParams(bundles, presets);
    if (answers.all) {
      return { all: true, bundleId: answers.bundleId };
    }
    bundleId = answers.bundleId;
    preset = answers.preset;
  }

  // ---------

  const env = extractEnv(preset);

  if (!env) {
    switchLogger.error('Could not find env');
    return;
  }

  switchLogger.log(`env: ${env}`);

  // ---------

  const override = { bundle: {}, fox: {}, custom: {} };
  const foxPackageJSON = JSON.parse(fs.readFileSync('../fox/package.json', 'utf8'));
  const appVersion = readProjectVersion();

  const subtitle = getSubtitle(bundles[bundleId])

  override.fox.version = foxPackageJSON.version;
  override.bundle.id = bundleId;
  override.bundle.title = getTitle(core);
  override.bundle.version = appVersion;
  override.bundle.versionCode = toVersionNumber(appVersion);
  override.bundle.platform = preset.platform;
  override.bundle.env = env;

  if (subtitle) {
    override.bundle.subtitle = getSubtitle(bundles[bundleId]);
  }

  if (core.useNotifications !== undefined) {
    override.custom.useNotifications = core.useNotifications;
  }

  // ---------

  let overrideByEnv;

  try {
    overrideByEnv = ini.parse(fs.readFileSync(`./override.${env}.cfg`, 'utf8'));
  } catch (e) {
    overrideByEnv = {};
  }

  // ---------

  let secretByEnv;

  try {
    secretByEnv = ini.parse(fs.readFileSync(`./secret.${env}.cfg`, 'utf8'));
  } catch (e) {
    secretByEnv = {};
  }

  // ---------

  override.custom = {
    ...override.custom,
    ...overrideByEnv,
    ...secretByEnv
  };

  // ---------

  const dataDisplay = {};
  Object.keys(override.bundle).forEach((key) => {
    dataDisplay[`[bundle] ${key}`] = override.bundle[key];
  });
  Object.keys(override.custom).forEach((key) => {
    dataDisplay[`[custom] ${key}`] = key.includes('secret') ? 'xxx' : override.custom[key];
  });
  switchLogger.data(dataDisplay);

  // ---------

  fs.writeFileSync(OVERRIDE_CFG, ini.stringify(override));
  switchLogger.success('Bundle ready');

  return { bundleId, preset, env };
};

// -----------------------------------------------------------------------------

export default switchBundle;
