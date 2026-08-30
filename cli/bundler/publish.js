// -----------------------------------------------------------------------------

import fs from 'fs';
import path from 'path';
import shell from 'shelljs';
import inquirer from 'inquirer';
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

const payloadVersion = (report) => {
  const versions = [...new Set(report.map(({version}) => version).filter(Boolean))];
  return versions.length === 1 ? versions[0] : null;
};

const confirmPayload = async ({title, appId, login, branch, contentRoot, projectVersion, version, report}) => {
  const details = {
    app: `${title} (appId ${appId})`,
    login,
    branch: branch || '(none — build stays unassigned)',
    contentRoot,
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

  if (version !== projectVersion) {
    steamLogger.warn(
      `payload is ${version} while project.godot is ${projectVersion} — re-run \`fox export\` on this env to ship ${projectVersion}`
    );
  }

  const {go} = await inquirer.prompt([
    {
      message: `upload ${version} to appId ${appId}${branch ? ` on branch "${branch}"` : ''}?`,
      name: 'go',
      type: 'confirm',
      // Agreeing with the repo is the ordinary case and defaults to yes; any
      // disagreement makes a blind enter mean "no", never "ship it anyway".
      default: version === projectVersion && !mismatched.length
    }
  ]);

  return go;
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

  const projectVersion = readProjectVersion();
  const absoluteContentRoot = path.resolve(process.cwd(), contentRoot);

  steamLogger.log(`Publishing ${core.title} (appId ${appId})`);

  const report = verifyContent(absoluteContentRoot, depots);

  if (!report) {
    return;
  }

  const version = payloadVersion(report) || projectVersion;

  const confirmed = await confirmPayload({
    title: core.title,
    appId,
    login,
    branch,
    contentRoot: absoluteContentRoot,
    projectVersion,
    version,
    report
  });

  if (!confirmed) {
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
