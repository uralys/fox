// -----------------------------------------------------------------------------

import fs from 'fs';
import path from 'path';
import shell from 'shelljs';
import inquirer from 'inquirer';
import {spawn} from 'child_process';

// -----------------------------------------------------------------------------

import {createLogger, foxLogger} from '../logger.js';
import {readProjectVersion} from './tag.js';
import exportBundle, {envChip} from './export.js';
import createSteamcmdLog from './steamcmd-log.js';

// -----------------------------------------------------------------------------

const steamLogger = createLogger({name: 'Steam', color: 'magenta'});

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
// weeks-old bytes under a fresh build number. Godot bakes ProjectSettings into
// `project.binary` inside the PCK, so the version and env of those exact bytes
// are readable on disk — that reading, not the repo, is what gets confirmed and
// what names the build on Steamworks.

const SCANNED_EXTENSIONS = ['.pck', '.exe', '.x86_64'];

const readBakedValue = (buffer, key) => {
  const needle = Buffer.from(`bundle/${key}`, 'latin1');

  let at = buffer.indexOf(needle);

  while (at >= 0) {
    // `bundle/version` is also the prefix of `bundle/versionCode`: a printable
    // byte right after the key means we landed on the longer one.
    const next = buffer[at + needle.length];

    if (next !== undefined && next < 0x21) {
      const window = buffer.toString('latin1', at, at + 256);
      const match = window.match(new RegExp(`bundle/${key}[^\\x21-\\x7e]+([\\x21-\\x7e]+)`));

      if (match) {
        return match[1];
      }
    }

    at = buffer.indexOf(needle, at + 1);
  }

  return null;
};

const readBakedBundle = (depotPath, files) => {
  const scanned = SCANNED_EXTENSIONS.map((extension) =>
    files.find((file) => file.endsWith(extension))
  ).find(Boolean);

  if (!scanned) {
    return {version: null, env: null};
  }

  try {
    const buffer = fs.readFileSync(path.join(depotPath, scanned));
    return {
      version: readBakedValue(buffer, 'version'),
      env: readBakedValue(buffer, 'env')
    };
  } catch (e) {
    return {version: null, env: null};
  }
};

const newestMtime = (depotPath, files) => {
  const stamps = files
    .map((file) => {
      try {
        return fs.statSync(path.join(depotPath, file)).mtime.getTime();
      } catch (e) {
        return null;
      }
    })
    .filter(Boolean);

  return stamps.length ? new Date(Math.max(...stamps)) : null;
};

const formatStamp = (stamp) => {
  if (!stamp) {
    return 'unknown';
  }

  const local = new Date(stamp.getTime() - stamp.getTimezoneOffset() * 60000);
  return local.toISOString().slice(0, 16).replace('T', ' ');
};

const verifyContent = (contentRoot, depots) => {
  const report = [];

  for (const [depotId, folder] of Object.entries(depots)) {
    const depotPath = path.resolve(contentRoot, folder);

    if (!fs.existsSync(depotPath)) {
      steamLogger.error(`Depot ${depotId}: missing folder ${depotPath} — run "fox export" first`);
      return null;
    }

    const files = fs.readdirSync(depotPath).filter((f) => !f.startsWith('.'));
    if (files.length === 0) {
      steamLogger.error(`Depot ${depotId}: ${depotPath} is empty`);
      return null;
    }

    const {version, env} = readBakedBundle(depotPath, files);
    report.push({depotId, folder, files: files.length, version, env, exportedAt: newestMtime(depotPath, files)});
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

const confirmPayload = async ({title, appId, login, branch, contentRoot, env, projectVersion, version, report}) => {
  // The env is read back from the payload whenever the depots carry it, so the
  // chip names what is IN the folder rather than what was asked for.
  const bakedEnv = payloadEnv(report) || env;

  const details = {
    app: `${title} (appId ${appId})`,
    login,
    branch: branch || '(none — build stays unassigned)',
    contentRoot,
    env: envChip(bakedEnv),
    version: `${version}${version === projectVersion ? '' : ` (project.godot says ${projectVersion})`}`
  };

  report.forEach(({depotId, folder, files, version: depotVersion, env, exportedAt}) => {
    details[`depot ${depotId}`] =
      `${folder}/ — ${depotVersion || 'version unknown'} ${env ? `(${env})` : ''} — ` +
      `${files} files — exported ${formatStamp(exportedAt)}`;
  });

  steamLogger.data(details);

  const mismatched = report.filter(({version: depotVersion}) => depotVersion && depotVersion !== version);

  if (mismatched.length) {
    steamLogger.warn('depots disagree on the version — check what you exported');
  }

  const target = `(${envChip(bakedEnv)}) to appId ${appId}${branch ? ` on branch "${branch}"` : ''}`;

  // When the payload matches the repo there is one sensible answer, so a plain
  // confirm is enough. When it does not, refusing is not the useful reply — the
  // useful reply is the export that would fix it, offered first and by default.
  if (version === projectVersion && !mismatched.length) {
    const {go} = await inquirer.prompt([
      {message: `upload ${version} ${target}?`, name: 'go', type: 'confirm', default: true}
    ]);

    return go ? UPLOAD : EXIT;
  }

  steamLogger.warn(`payload is ${version} while project.godot is ${projectVersion}`);

  const {choice} = await inquirer.prompt([
    {
      message: `payload is ${version}, what now?`,
      name: 'choice',
      type: 'list',
      choices: [
        {name: `fox export ${envChip(env)} now, then publish ${projectVersion}`, value: EXPORT},
        {name: `upload ${version} anyway ${target}`, value: UPLOAD},
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

const PUBLISH_TARGETS = [
  {arg: 'game', key: 'steam', label: 'game'},
  {arg: 'demo', key: 'steamDemo', label: 'demo'}
];

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

const availableTargets = (config) => PUBLISH_TARGETS.filter(({key}) => config[key]);

const inquireTarget = async (config, lastKey) => {
  const targets = availableTargets(config);

  if (targets.length < 2) {
    return targets[0] && targets[0].key;
  }

  const ordered = [
    ...targets.filter(({key}) => key === lastKey),
    ...targets.filter(({key}) => key !== lastKey)
  ];

  const {key} = await inquirer.prompt([
    {
      message: 'publish',
      name: 'key',
      type: 'list',
      choices: ordered.map(({key: value, label}) => ({
        name: `${label} (appId ${config[value].appId})`,
        value
      }))
    }
  ]);

  return key;
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

const publish = async (settings, params) => {
  const {core, config} = settings;

  const state = readState();

  // Arguments still win, so a scripted `fox publish demo staging` never stops on
  // a prompt; only what is missing is asked for.
  const argTarget = PUBLISH_TARGETS.find(({arg}) => arg === params[0]);
  const argBranch = argTarget ? params[1] : params[0];

  const configKey = argTarget ? argTarget.key : await inquireTarget(config, state.target);

  if (!configKey) {
    foxLogger.error('Missing "publish.steam" or "publish.steamDemo" in fox.config.json');
    return;
  }

  const steam = config[configKey];

  if (!steam) {
    foxLogger.error(`Missing "publish.${configKey}" in fox.config.json`);
    return;
  }

  const isDemo = configKey === 'steamDemo';
  const remembered = (state.branches || {})[configKey];

  const branch =
    argBranch !== undefined && argBranch !== null
      ? argBranch
      : await inquireBranch(steam, remembered === undefined ? steam.branch : remembered);

  writeState({
    ...state,
    target: configKey,
    branches: {...(state.branches || {}), [configKey]: branch}
  });

  const {appId, login, contentRoot, depots} = steam;

  if (!appId || !login || !depots) {
    steamLogger.error(`publish.${configKey} requires appId, login and depots`);
    return;
  }

  if (isPlaceholder(login)) {
    steamLogger.error(`Set your Steam partner login in fox.config.json (got placeholder "${login}")`);
    return;
  }

  if (isPlaceholder(appId)) {
    steamLogger.error(
      `Create the demo app in Steamworks, then set publish.${configKey}.appId/depots in fox.config.json (got placeholder "${appId}")`
    );
    return;
  }

  // ---------

  const projectVersion = readProjectVersion();
  const absoluteContentRoot = path.resolve(process.cwd(), contentRoot);

  steamLogger.log(`Publishing ${core.title} (appId ${appId})`);

  // The env whose presets fill this content root: what `fox export` must be run
  // on for the payload to become the version the repo is at.
  const env = isDemo ? 'demo' : 'release';

  let report = verifyContent(absoluteContentRoot, depots);

  if (!report) {
    return;
  }

  let version = payloadVersion(report) || projectVersion;
  let decision = EXIT;

  // One loop, driven entirely by the answers: exporting brings us back to the
  // same table, now describing the bytes that were just written.
  for (;;) {
    decision = await confirmPayload({
      title: core.title,
      appId,
      login,
      branch,
      contentRoot: absoluteContentRoot,
      env,
      projectVersion,
      version,
      report
    });

    if (decision !== EXPORT) {
      break;
    }

    steamLogger.log(`Running fox export on env "${env}"...`);

    if (!(await exportBundle(settings, {forcedEnv: env}))) {
      steamLogger.error('Export failed — nothing uploaded');
      return;
    }

    report = verifyContent(absoluteContentRoot, depots);

    if (!report) {
      return;
    }

    version = payloadVersion(report) || projectVersion;
  }

  if (decision !== UPLOAD) {
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

  const demoSuffix = isDemo ? ' (demo)' : '';
  const appBuildPath = writeAppBuildScript(steamDir, {
    appId,
    desc: `${core.title} ${version}${demoSuffix}${branch ? ` (${branch})` : ''}`,
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
