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

const PLATFORM_BY_PROCESS = {
  darwin: 'macOS',
  win32: 'Windows Desktop',
  linux: 'Linux'
};

// `prod` is the public label of the `release` env.
// `staging` stays supported internally but is hidden from the prompt.
const ENV_CHOICES = [
  {name: 'debug', value: 'debug'},
  {name: 'demo', value: 'demo'},
  {name: 'prod', value: 'release'}
];

const SUPPORTED_ENVS = ['debug', 'staging', 'release', 'demo'];

// -----------------------------------------------------------------------------

export const hostPlatform = () => PLATFORM_BY_PROCESS[process.platform] || 'Linux';

// -----------------------------------------------------------------------------

export const writeOverride = (settings, {bundleId, platform, env}) => {
  const {core, bundles} = settings;

  if (!SUPPORTED_ENVS.includes(env)) {
    switchLogger.error(`env:${env} is not supported, use one of [${SUPPORTED_ENVS}]`);
    return null;
  }

  const override = {bundle: {}, fox: {}, custom: {}};
  const foxPackageJSON = JSON.parse(fs.readFileSync('../fox/package.json', 'utf8'));
  const appVersion = readProjectVersion();
  const subtitle = getSubtitle(bundles[bundleId]);

  override.fox.version = foxPackageJSON.version;
  override.bundle.id = bundleId;
  override.bundle.title = getTitle(core);
  override.bundle.version = appVersion;
  override.bundle.versionCode = toVersionNumber(appVersion);
  override.bundle.platform = platform;
  override.bundle.env = env;

  if (subtitle) {
    override.bundle.subtitle = subtitle;
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

  return override;
};

// -----------------------------------------------------------------------------

const inquireParams = async (bundles) => {
  const bundleIds = Object.keys(bundles);
  const singleBundleId = bundleIds.length > 1 ? null : bundleIds[0];

  const questions = [
    {
      message: 'env',
      name: 'env',
      type: 'list',
      choices: ENV_CHOICES
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

  return {
    bundleId: answers.bundleId || singleBundleId,
    env: answers.env
  };
};

// -----------------------------------------------------------------------------

const switchBundle = async (settings) => {
  const {bundles} = settings;
  switchLogger.log('Selecting env...');

  if (!bundles) {
    switchLogger.error('Missing bundles in fox.config.json');
    return;
  }

  const {bundleId, env} = await inquireParams(bundles);
  const platform = hostPlatform();

  switchLogger.log(`env: ${env} — platform: ${platform}`);

  const override = writeOverride(settings, {bundleId, platform, env});

  if (!override) {
    switchLogger.error('Could not write override.cfg');
    return;
  }

  switchLogger.success('Bundle ready');

  return {bundleId, env};
};

// -----------------------------------------------------------------------------

export default switchBundle;
