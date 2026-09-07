// -----------------------------------------------------------------------------

import fs from 'fs';
import path from 'path';
import shell from 'shelljs';
import inquirer from 'inquirer';
import {spawn} from 'child_process';

// -----------------------------------------------------------------------------

import {createLogger, foxLogger} from '../logger.js';
import {readProjectVersion} from './tag.js';
import exportBundle, {envChip, targetChip} from './export.js';
import createSteamcmdLog from './steamcmd-log.js';
import {readBakedBundle, newestMtime, formatStamp} from './baked-bundle.js';
import {
  exportRoot,
  publishableEnvs,
  publishableTargets,
  readPublishConfig,
  TARGET_CHOICES
} from './publish-config.js';

// -----------------------------------------------------------------------------

const steamLogger = createLogger({name: 'Steam', color: 'magenta'});
const itchLogger = createLogger({name: 'itch', color: 'red'});

const STEAM_DIR = '_build/steam';

// -----------------------------------------------------------------------------

const vdfBlock = (entries, indent = 0) => {
  const inner = '\t'.repeat(indent + 1);

  const lines = Object.entries(entries).map(([key, value]) => {
    if (Array.isArray(value)) {
      // VDF allows a key to repeat (e.g. several FileExclusion entries).
      return value.map((item) => `${inner}"${key}"\t"${item}"`).join('\n');
    }
    if (value !== null && typeof value === 'object') {
      return `${inner}"${key}"\n${inner}{\n${vdfBlock(value, indent + 1)}\n${inner}}`;
    }
    return `${inner}"${key}"\t"${value}"`;
  });

  return lines.join('\n');
};

const writeVdf = (filePath, root) => {
  const [key] = Object.keys(root);
  const content = `"${key}"\n{\n${vdfBlock(root[key], 0)}\n}\n`;
  fs.writeFileSync(filePath, content);
};

// -----------------------------------------------------------------------------

const writeDepotScript = (steamDir, depotId, contentRoot) => {
  const filePath = path.join(steamDir, `depot_${depotId}.vdf`);

  writeVdf(filePath, {
    DepotBuild: {
      DepotID: depotId,
      ContentRoot: contentRoot,
      FileMapping: {
        LocalPath: '*',
        DepotPath: '.',
        recursive: '1'
      },
      FileExclusion: ['*.pdb', 'steam_appid.txt']
    }
  });

  return filePath;
};

const writeAppBuildScript = (steamDir, {appId, desc, contentRoot, setlive, depots}) => {
  const filePath = path.join(steamDir, `app_build_${appId}.vdf`);

  writeVdf(filePath, {
    appbuild: {
      appid: appId,
      desc,
      buildoutput: path.join(steamDir, 'output'),
      contentroot: contentRoot,
      setlive,
      depots
    }
  });

  return filePath;
};

// -----------------------------------------------------------------------------
// What is uploaded is whatever sits in the export folder, which is NOT what
// `project.godot` says: a publish run after an export left on another env ships
// weeks-old bytes under a fresh build number. The version and env of those exact
// bytes are read back from the payload (see baked-bundle.js) — that reading, not
// the repo, is what gets confirmed and what names the build on Steamworks.

// `slots` maps a store-side name to a folder under the content root: a Steam
// depot id, an itch channel. Both stores upload folder by folder, so both are
// verified the same way.
const verifyContent = (contentRoot, slots, logger) => {
  const report = [];

  for (const [slot, folder] of Object.entries(slots)) {
    const slotPath = path.resolve(contentRoot, folder);

    if (!fs.existsSync(slotPath)) {
      logger.error(`${slot}: missing folder ${slotPath} — run "fox export" first`);
      return null;
    }

    const files = fs.readdirSync(slotPath).filter((f) => !f.startsWith('.'));
    if (files.length === 0) {
      logger.error(`${slot}: ${slotPath} is empty`);
      return null;
    }

    const {version, env} = readBakedBundle(slotPath, files);
    report.push({slot, folder, files: files.length, version, env, exportedAt: newestMtime(slotPath, files)});
  }

  return report;
};

// -----------------------------------------------------------------------------
// The confirmation exists for one line: the version actually baked in the
// depots. It is the answer to "what am I about to put on that branch", and it
// is deliberately read from the payload rather than from the repo, because the
// two disagreeing is precisely the accident this guards against.

const UPLOAD = 'upload';
const EXPORT = 'export';
const EXIT = 'exit';

const payloadVersion = (report) => {
  const versions = [...new Set(report.map(({version}) => version).filter(Boolean))];
  return versions.length === 1 ? versions[0] : null;
};

const payloadEnv = (report) => {
  const envs = [...new Set(report.map(({env}) => env).filter(Boolean))];
  return envs.length === 1 ? envs[0] : null;
};

const confirmPayload = async ({logger, title, details, contentRoot, env, target, projectVersion, version, report}) => {
  // The env is read back from the payload whenever the folders carry it, so the
  // chip names what is IN the folder rather than what was asked for.
  const bakedEnv = payloadEnv(report) || env;

  const shown = {
    ...details,
    contentRoot,
    env: envChip(bakedEnv),
    version: `${version}${version === projectVersion ? '' : ` (project.godot says ${projectVersion})`}`
  };

  report.forEach(({slot, folder, files, version: slotVersion, env: slotEnv, exportedAt}) => {
    shown[slot] =
      `${folder}/ — ${slotVersion || 'version unknown'} ${slotEnv ? `(${slotEnv})` : ''} — ` +
      `${files} files — exported ${formatStamp(exportedAt)}`;
  });

  logger.data(shown);

  const mismatched = report.filter(({version: slotVersion}) => slotVersion && slotVersion !== version);

  if (mismatched.length) {
    logger.warn('folders disagree on the version — check what you exported');
  }

  // The store is half of the answer to "what am I about to publish": the same
  // version and env go to two different places, so the chip names the target.
  const destination = `(${envChip(bakedEnv)}) to ${title} on ${targetChip(target)}`;

  // When the payload matches the repo there is one sensible answer, so a plain
  // confirm is enough. When it does not, refusing is not the useful reply — the
  // useful reply is the export that would fix it, offered first and by default.
  if (version === projectVersion && !mismatched.length) {
    const {go} = await inquirer.prompt([
      {message: `upload ${version} ${destination}?`, name: 'go', type: 'confirm', default: true}
    ]);

    return go ? UPLOAD : EXIT;
  }

  logger.warn(`payload is ${version} while project.godot is ${projectVersion}`);

  const {choice} = await inquirer.prompt([
    {
      message: `payload is ${version}, what now?`,
      name: 'choice',
      type: 'list',
      choices: [
        {name: `fox export ${envChip(env)} on ${targetChip(target)} now, then publish ${projectVersion}`, value: EXPORT},
        {name: `upload ${version} anyway ${destination}`, value: UPLOAD},
        {name: 'exit', value: EXIT}
      ]
    }
  ]);

  return choice;
};

// -----------------------------------------------------------------------------

const runSteamcmd = (login, appBuildPath, depots) =>
  new Promise((resolve) => {
    steamLogger.log('Uploading to SteamPipe (steamcmd)...');

    const steamLog = createSteamcmdLog(steamLogger, depots);

    // stdin stays inherited: steamcmd may still ask for a Steam Guard code, and
    // that prompt has to reach the real terminal.
    const steamcmd = spawn(
      'steamcmd',
      ['+login', login, '+run_app_build', appBuildPath, '+quit'],
      {stdio: ['inherit', 'pipe', 'pipe']}
    );

    steamcmd.stdout.on('data', (chunk) => steamLog.push(chunk.toString()));
    steamcmd.stderr.on('data', (chunk) => steamLog.push(chunk.toString()));

    steamcmd.on('close', (code) => {
      steamLog.flush();

      if (code !== 0) {
        steamLogger.error(`steamcmd exited with code ${code}`);
        resolve(false);
        return;
      }
      resolve(true);
    });
  });

// -----------------------------------------------------------------------------
// `fox publish` alone asks what it is about to publish instead of relying on
// arguments typed from memory. The last answers are remembered under _build,
// which is gitignored: this is a convenience for one machine, never a shared
// setting — fox.config.json stays the source of truth for what a target IS.

const STATE_FILE = path.join(STEAM_DIR, 'last-publish.json');

const NO_BRANCH = '';
const OTHER_BRANCH = '\u0000other';

const readState = () => {
  try {
    return JSON.parse(fs.readFileSync(path.resolve(process.cwd(), STATE_FILE), 'utf8'));
  } catch (e) {
    return {};
  }
};

const writeState = (state) => {
  const filePath = path.resolve(process.cwd(), STATE_FILE);
  shell.mkdir('-p', path.dirname(filePath));
  fs.writeFileSync(filePath, `${JSON.stringify(state, null, 2)}\n`);
};

const targetLabel = (target) => {
  const choice = TARGET_CHOICES.find(({value}) => value === target);
  return choice ? choice.name : target;
};

const inquireTarget = async (settings, lastTarget) => {
  const targets = publishableTargets(settings);

  if (targets.length < 2) {
    return targets[0] || null;
  }

  const ordered = [
    ...targets.filter((target) => target === lastTarget),
    ...targets.filter((target) => target !== lastTarget)
  ];

  const {target} = await inquirer.prompt([
    {
      message: 'store',
      name: 'target',
      type: 'list',
      choices: ordered.map((value) => ({
        name: `${targetChip(value)} ${colorless(publishableEnvs(settings, value).join(', '))}`,
        value
      }))
    }
  ]);

  return target;
};

const colorless = (text) => `(${text})`;

const inquireEnv = async (settings, target, lastEnv) => {
  const envs = publishableEnvs(settings, target);

  if (envs.length < 2) {
    return envs[0] || null;
  }

  const ordered = [...envs.filter((env) => env === lastEnv), ...envs.filter((env) => env !== lastEnv)];

  const {env} = await inquirer.prompt([
    {
      message: 'env',
      name: 'env',
      type: 'list',
      choices: ordered.map((value) => {
        const {appId} = readPublishConfig(settings, target, value);
        return {name: `${envChip(value)}${appId ? ` (appId ${appId})` : ''}`, value};
      })
    }
  ]);

  return env;
};

const inquireBranch = async (steam, lastBranch) => {
  const known = [...new Set([lastBranch, steam.branch].filter((branch) => branch))];

  const {branch} = await inquirer.prompt([
    {
      message: 'branch',
      name: 'branch',
      type: 'list',
      choices: [
        ...known.map((value) => ({name: value, value})),
        {name: '(none — build stays unassigned)', value: NO_BRANCH},
        {name: 'other...', value: OTHER_BRANCH}
      ]
    }
  ]);

  if (branch !== OTHER_BRANCH) {
    return branch;
  }

  const {typed} = await inquirer.prompt([
    {message: 'branch name', name: 'typed', type: 'input'}
  ]);

  return typed.trim();
};

// -----------------------------------------------------------------------------

const isPlaceholder = (value) => typeof value === 'string' && value.startsWith('<');

// -----------------------------------------------------------------------------
// The payload gate, shared by every store: read back what actually sits in the
// export folder, show it, and let the answer be the export that would fix it.
// Returns the version to publish, or null when nothing should be uploaded.

const settleOnPayload = async ({settings, logger, title, env, target, contentRoot, folders, details}) => {
  const projectVersion = readProjectVersion();
  let report = verifyContent(contentRoot, folders, logger);

  if (!report) {
    return null;
  }

  let version = payloadVersion(report) || projectVersion;

  for (;;) {
    const decision = await confirmPayload({
      logger,
      title,
      details,
      contentRoot,
      env,
      target,
      projectVersion,
      version,
      report
    });

    if (decision !== EXPORT) {
      return decision === UPLOAD ? version : null;
    }

    logger.log(`Running fox export on "${env}" for "${target}"...`);

    if (!(await exportBundle(settings, {forcedEnv: env, forcedTarget: target}))) {
      logger.error('Export failed — nothing uploaded');
      return null;
    }

    report = verifyContent(contentRoot, folders, logger);

    if (!report) {
      return null;
    }

    version = payloadVersion(report) || projectVersion;
  }
};

// -----------------------------------------------------------------------------
// itch.io — butler pushes one folder per channel, and a channel name carrying
// "windows" / "linux" / "osx" is what tells itch which platform it is.

const runButler = (folder, itchTarget, version) =>
  new Promise((resolve) => {
    itchLogger.log(`butler push ${folder} -> ${itchTarget}`);

    const butler = spawn(
      'butler',
      ['push', folder, itchTarget, '--userversion', version],
      {stdio: ['inherit', 'inherit', 'inherit']}
    );

    butler.on('close', (code) => resolve(code === 0));
  });

const publishToItch = async (settings, {env, store}) => {
  const {core} = settings;
  const {user, game, channels} = store;

  if (!user || !game || !channels) {
    itchLogger.error('publish.itch requires user, game, and envs.<env>.channels');
    return;
  }

  if (isPlaceholder(user) || isPlaceholder(game)) {
    itchLogger.error(`Set your itch.io user and game in fox.config.json (got "${user}/${game}")`);
    return;
  }

  const contentRoot = path.resolve(process.cwd(), store.contentRoot || exportRoot(env, 'itch'));

  itchLogger.log(`Publishing ${core.title} to ${user}/${game}`);

  const details = {
    page: `https://${user}.itch.io/${game}`,
    env: envChip(env)
  };

  const version = await settleOnPayload({
    settings,
    logger: itchLogger,
    title: core.title,
    env,
    target: 'itch',
    contentRoot,
    folders: channels,
    details
  });

  if (!version) {
    itchLogger.done('Nothing uploaded');
    return;
  }

  if (!shell.which('butler')) {
    itchLogger.error('butler not found — install it: https://itch.io/docs/butler/installing.html');
    return;
  }

  for (const [channel, folder] of Object.entries(channels)) {
    const ok = await runButler(
      path.resolve(contentRoot, folder),
      `${user}/${game}:${channel}`,
      version
    );

    if (!ok) {
      itchLogger.error(`butler failed on channel "${channel}" — later channels not pushed`);
      return;
    }
  }

  itchLogger.done(`Pushed ${version} to https://${user}.itch.io/${game}`);
};

// -----------------------------------------------------------------------------

const publish = async (settings, params) => {
  const {config} = settings;

  const state = readState();

  // Arguments still win, so a scripted run never stops on a prompt; only what is
  // missing is asked for. A first argument naming an env rather than a store is
  // read as one — `fox publish demo staging` predates the target axis and still
  // means the demo on Steam.
  const knownTargets = publishableTargets({publish: config});
  const argTarget = knownTargets.includes(params[0]) ? params[0] : null;
  const rest = argTarget ? params.slice(1) : params;

  const target = argTarget || (await inquireTarget({publish: config}, state.target));

  if (!target) {
    foxLogger.error('Nothing to publish: fox.config.json declares no "publish.<store>"');
    return;
  }

  const knownEnvs = publishableEnvs({publish: config}, target);
  const argEnv = knownEnvs.includes(rest[0]) ? rest[0] : null;
  const argBranch = argEnv ? rest[1] : rest[0];

  const env = argEnv || (await inquireEnv({publish: config}, target, (state.envs || {})[target]));

  if (!env) {
    foxLogger.error(`publish.${target} declares no envs in fox.config.json`);
    return;
  }

  const store = readPublishConfig({publish: config}, target, env);

  writeState({
    ...state,
    target,
    envs: {...(state.envs || {}), [target]: env}
  });

  if (target === 'itch') {
    return publishToItch(settings, {env, store});
  }

  return publishToSteam(settings, {env, store, argBranch, state});
};

// -----------------------------------------------------------------------------

const publishToSteam = async (settings, {env, store, argBranch, state}) => {
  const {core} = settings;

  const remembered = (state.branches || {})[env];

  const branch =
    argBranch !== undefined && argBranch !== null
      ? argBranch
      : await inquireBranch(store, remembered === undefined ? store.branch : remembered);

  writeState({...readState(), branches: {...(state.branches || {}), [env]: branch}});

  const {appId, login, depots} = store;

  if (!appId || !login || !depots) {
    steamLogger.error(`publish.steam.envs.${env} requires appId, login and depots`);
    return;
  }

  if (isPlaceholder(login)) {
    steamLogger.error(`Set your Steam partner login in fox.config.json (got placeholder "${login}")`);
    return;
  }

  if (isPlaceholder(appId)) {
    steamLogger.error(
      `Create the app in Steamworks, then set publish.steam.envs.${env}.appId/depots in fox.config.json (got placeholder "${appId}")`
    );
    return;
  }

  // ---------

  const absoluteContentRoot = path.resolve(
    process.cwd(),
    store.contentRoot || exportRoot(env, 'steam')
  );

  steamLogger.log(`Publishing ${core.title} (appId ${appId})`);

  const version = await settleOnPayload({
    settings,
    logger: steamLogger,
    title: core.title,
    env,
    target: 'steam',
    contentRoot: absoluteContentRoot,
    folders: depots,
    details: {
      app: `${core.title} (appId ${appId})`,
      login,
      branch: branch || '(none — build stays unassigned)',
      env: envChip(env)
    }
  });

  if (!version) {
    steamLogger.done('Nothing uploaded');
    return;
  }

  // ---------

  const steamDir = path.resolve(process.cwd(), STEAM_DIR);
  shell.mkdir('-p', path.join(steamDir, 'output'));

  const depotScripts = {};
  for (const [depotId, folder] of Object.entries(depots)) {
    writeDepotScript(steamDir, depotId, path.resolve(absoluteContentRoot, folder));
    depotScripts[depotId] = `depot_${depotId}.vdf`;
  }

  const envSuffix = env === 'release' ? '' : ` (${env})`;
  const appBuildPath = writeAppBuildScript(steamDir, {
    appId,
    desc: `${core.title} ${version}${envSuffix}${branch ? ` (${branch})` : ''}`,
    contentRoot: absoluteContentRoot,
    setlive: branch,
    depots: depotScripts
  });

  steamLogger.success(`Generated VDF scripts in ${STEAM_DIR}/`);

  // ---------

  if (!shell.which('steamcmd')) {
    steamLogger.error('steamcmd not found — install it: https://developer.valvesoftware.com/wiki/SteamCMD');
    return;
  }

  const ok = await runSteamcmd(login, appBuildPath, depots);
  if (!ok) {
    steamLogger.error('Publish failed');
    return;
  }

  if (branch) {
    steamLogger.done(`Build uploaded and set live on branch "${branch}"`);
  } else {
    steamLogger.done(
      `Build uploaded — assign it to a branch in Steamworks › SteamPipe › Builds: https://partner.steamgames.com/apps/builds/${appId}`
    );
  }

  return true;
};

// -----------------------------------------------------------------------------

export default publish;
