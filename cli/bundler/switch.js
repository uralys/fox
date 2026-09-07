// -----------------------------------------------------------------------------

import fs from 'fs';
import inquirer from 'inquirer';

// -----------------------------------------------------------------------------

import {switchLogger} from '../logger.js';
import ini from './ini.js';
import {DEFAULT_TARGET} from './resolve-env-preset.js';
import {readPublishConfig, SUPPORTED_TARGETS, TARGET_CHOICES} from './publish-config.js';
import {toVersionNumber} from './versioning.js';
import {readProjectVersion} from './tag.js';

// Kept local rather than imported from export.js: the two modules already
// import each other, and this is a one-word constant.
const WEB = 'Web';

// The env whose secret must never become public, whatever the platform.
const SEALED_ENV = 'release';
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
//
// The env says what the build CONTAINS. Where it is published is the OTHER axis,
// `target` — see resolve-env-preset.js. A value like "itch" never belongs here.
export const ENV_CHOICES = [
  {name: 'debug', value: 'debug'},
  {name: 'demo', value: 'demo'},
  {name: 'prod', value: 'release'}
];

const SUPPORTED_ENVS = ['debug', 'staging', 'release', 'demo'];

// -----------------------------------------------------------------------------

export const hostPlatform = () => PLATFORM_BY_PROCESS[process.platform] || 'Linux';

// -----------------------------------------------------------------------------

// A WEB pck is downloaded by every visitor and readable with a text editor, so
// whatever it carries is PUBLIC. That is a verdict on the KEY, not on the
// platform: a demo key is MEANT to be public — it is registered on its own row
// server side and revocable alone, without touching the full game — while the
// release key never is. Hence the rule, and it is the single place expressing
// it: a web build bakes its secret, EXCEPT on `release`.
//
// Both doors into the pck ask this question — project.godot (patched by
// export.js) and override.cfg (written below), since Godot merges the latter
// into ProjectSettings and serializes the result into project.binary.
export const bakesSecret = (platform, env) => platform !== WEB || env !== SEALED_ENV;

// -----------------------------------------------------------------------------

// Steam app_id per env, and ONLY when the build is aimed at Steam: the demo runs
// as a separate Steam app (own Cloud storage), so the build must init Steam against
// the right id, while an itch build must carry none at all — baking one would make
// it ask for a Steam client that is not there. `override.cfg` is loaded before the
// autoloads, overriding `project.godot [steam] initialization/app_id` — the
// committed project keeps `app_id=0`, fox.config.json is the single source of truth.
export const resolveSteamAppId = ({publish}, env, target = DEFAULT_TARGET) => {
  if (target !== 'steam') {
    return null;
  }

  const appId = readPublishConfig({publish}, 'steam', env).appId;

  if (!appId || String(appId).startsWith('<')) {
    return null;
  }

  return appId;
};

// -----------------------------------------------------------------------------

export const writeOverride = (settings, {bundleId, platform, env, target = DEFAULT_TARGET}) => {
  const {core, bundles} = settings;

  if (!SUPPORTED_ENVS.includes(env)) {
    switchLogger.error(`env:${env} is not supported, use one of [${SUPPORTED_ENVS}]`);
    return null;
  }

  if (!SUPPORTED_TARGETS.includes(target)) {
    switchLogger.error(`target:${target} is not supported, use one of [${SUPPORTED_TARGETS}]`);
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
  override.bundle.target = target;

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

  // override.cfg is the second door into the pck: Godot merges it into
  // ProjectSettings and serializes the result into project.binary at export
  // time. Clearing project.godot alone (see patchProjectGodotSecrets) therefore
  // bakes the key anyway, through here — measured on a published build, whose
  // HTML5 pck carried the live HMAC key with the desktop fingerprint. Both
  // doors follow bakesSecret(), so a web RELEASE stays sealed while a web demo
  // ships the key it is supposed to sign with.
  let secretByEnv;

  if (!bakesSecret(platform, env)) {
    switchLogger.warn(
      `Web ${env} build: [custom] secrets kept OUT of override.cfg (a web pck is public)`
    );
    secretByEnv = {};
  } else {
    try {
      secretByEnv = ini.parse(fs.readFileSync(`./secret.${env}.cfg`, 'utf8'));
    } catch (e) {
      secretByEnv = {};
    }
  }

  // ---------

  override.custom = {
    ...override.custom,
    ...overrideByEnv,
    ...secretByEnv
  };

  // ---------

  const steamAppId = resolveSteamAppId(settings, env, target);

  if (steamAppId) {
    override.steam = {'initialization/app_id': steamAppId};
  }

  // ---------

  const dataDisplay = {};
  Object.keys(override.bundle).forEach((key) => {
    dataDisplay[`[bundle] ${key}`] = override.bundle[key];
  });
  Object.keys(override.custom).forEach((key) => {
    dataDisplay[`[custom] ${key}`] = key.includes('secret') ? 'xxx' : override.custom[key];
  });
  if (override.steam) {
    dataDisplay['[steam] initialization/app_id'] = override.steam['initialization/app_id'];
  }
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
    },
    {
      message: 'target',
      name: 'target',
      type: 'list',
      choices: TARGET_CHOICES
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
    env: answers.env,
    target: answers.target
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

  const {bundleId, env, target} = await inquireParams(bundles);
  const platform = hostPlatform();

  switchLogger.log(`env: ${env} — target: ${target} — platform: ${platform}`);

  const override = writeOverride(settings, {bundleId, platform, env, target});

  if (!override) {
    switchLogger.error('Could not write override.cfg');
    return;
  }

  switchLogger.success('Bundle ready');

  return {bundleId, env, target};
};

// -----------------------------------------------------------------------------

export default switchBundle;
