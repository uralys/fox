// -----------------------------------------------------------------------------

import fs from 'fs';
import path from 'path';
import shell from 'shelljs';
import {spawn} from 'child_process';

// -----------------------------------------------------------------------------

import {createLogger, foxLogger} from '../logger.js';
import {readProjectVersion} from './tag.js';

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

const verifyContent = (contentRoot, depots) => {
  for (const [depotId, folder] of Object.entries(depots)) {
    const depotPath = path.resolve(contentRoot, folder);

    if (!fs.existsSync(depotPath)) {
      steamLogger.error(`Depot ${depotId}: missing folder ${depotPath} — run "fox export" first`);
      return false;
    }

    const files = fs.readdirSync(depotPath).filter((f) => !f.startsWith('.'));
    if (files.length === 0) {
      steamLogger.error(`Depot ${depotId}: ${depotPath} is empty`);
      return false;
    }

    steamLogger.successCompact(`Depot ${depotId} → ${folder}/ (${files.length} files)`);
  }

  return true;
};

// -----------------------------------------------------------------------------

const runSteamcmd = (login, appBuildPath) =>
  new Promise((resolve) => {
    steamLogger.log('Uploading to SteamPipe (steamcmd)...');

    const steamcmd = spawn(
      'steamcmd',
      ['+login', login, '+run_app_build', appBuildPath, '+quit'],
      {stdio: [process.stdin, process.stdout, process.stderr]}
    );

    steamcmd.on('close', (code) => {
      if (code !== 0) {
        steamLogger.error(`steamcmd exited with code ${code}`);
        resolve(false);
        return;
      }
      resolve(true);
    });
  });

// -----------------------------------------------------------------------------

const isPlaceholder = (value) => typeof value === 'string' && value.startsWith('<');

const publish = async (settings, params) => {
  const {core, config} = settings;

  const isDemo = params[0] === 'demo';
  const configKey = isDemo ? 'steamDemo' : 'steam';
  const steam = isDemo ? config.steamDemo : config.steam;

  if (!steam) {
    foxLogger.error(`Missing "publish.${configKey}" in fox.config.json`);
    return;
  }

  const {appId, login, contentRoot, depots} = steam;
  const branch = (isDemo ? params[1] : params[0]) || steam.branch || '';

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

  const version = readProjectVersion();
  const absoluteContentRoot = path.resolve(process.cwd(), contentRoot);

  steamLogger.log(`Publishing ${core.title} ${version} (appId ${appId})`);
  steamLogger.data({
    appId,
    login,
    contentRoot: absoluteContentRoot,
    branch: branch || '(none — build stays unassigned)'
  });

  if (!verifyContent(absoluteContentRoot, depots)) {
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

  const ok = await runSteamcmd(login, appBuildPath);
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
