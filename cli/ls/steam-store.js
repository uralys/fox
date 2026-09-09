// -----------------------------------------------------------------------------
// The store half of `fox ls:steam`: what Steam actually serves, and what the
// last upload from this machine claimed to put there.
//
// Steam has no equivalent of butler's `userVersion`: appinfo knows a BuildID and
// a manifest per depot, never the version baked in the bytes. So the two sides
// are joined on the MANIFEST — the one identifier both halves name. steamcmd
// writes it under `_build/steam/output` on every upload, and appinfo hands back
// the one the branch currently points at: equal manifests mean the branch serves
// these exact depot bytes, whose version the local folder already told us.
//
// Reading appinfo needs a logged-in steamcmd, and it is the SAME cached session
// `fox publish` uses. It stays optional by design: no steamcmd, no session, no
// network — the listing simply reports its local half, exactly as an unreachable
// Deck does.

import fs from 'fs';
import path from 'path';
import shell from 'shelljs';
import {spawn} from 'child_process';

// -----------------------------------------------------------------------------

const STEAM_OUTPUT_DIR = '_build/steam/output';

// appinfo is read, never written, so a hung prompt is pure loss: stdin is closed
// so steamcmd cannot ask for a Steam Guard code it would never receive, and the
// call is bounded.
const APPINFO_TIMEOUT = 60 * 1000;

// The branch a build lands on when `setlive` is empty: nothing is assigned, and
// what the store serves is whatever "public" already pointed at.
export const DEFAULT_BRANCH = 'public';

// -----------------------------------------------------------------------------
// A minimal VDF reader: `app_info_print` prints quoted keys, quoted values and
// braces, which is all that is needed here. Anything else (comments, unquoted
// tokens) is not emitted by that command.

const parseVdf = (text) => {
  const root = {};
  const stack = [root];

  text.split('\n').forEach((raw) => {
    const line = raw.trim();

    if (line === '{') {
      return;
    }

    if (line === '}') {
      if (stack.length > 1) {
        stack.pop();
      }
      return;
    }

    const pair = line.match(/^"([^"]*)"\s+"([^"]*)"$/);

    if (pair) {
      stack[stack.length - 1][pair[1]] = pair[2];
      return;
    }

    const key = line.match(/^"([^"]*)"$/);

    if (key) {
      const child = {};
      stack[stack.length - 1][key[1]] = child;
      stack.push(child);
    }
  });

  return root;
};

// `app_info_print` prints its own chatter before the block; the app id opens it.
const appBlock = (stdout, appId) => {
  const start = stdout.indexOf(`"${appId}"`);

  if (start < 0) {
    return null;
  }

  const parsed = parseVdf(stdout.slice(start));

  return parsed[appId] || null;
};

// -----------------------------------------------------------------------------

const runSteamcmd = (login, appIds) =>
  new Promise((resolve) => {
    const commands = ['+login', login];

    appIds.forEach((appId) => commands.push('+app_info_print', appId));
    commands.push('+quit');

    // stdin is CLOSED, unlike `fox publish`: a listing must never sit on a Steam
    // Guard prompt, so a session that needs one fails fast and reports why.
    const steamcmd = spawn('steamcmd', commands, {stdio: ['ignore', 'pipe', 'pipe']});

    let stdout = '';
    let settled = false;

    const finish = (result) => {
      if (settled) {
        return;
      }
      settled = true;
      clearTimeout(watchdog);
      resolve(result);
    };

    const watchdog = setTimeout(() => {
      steamcmd.kill();
      finish({reachable: false, reason: `steamcmd did not answer in ${APPINFO_TIMEOUT / 1000}s`});
    }, APPINFO_TIMEOUT);

    steamcmd.stdout.on('data', (chunk) => {
      stdout += chunk.toString();
    });

    steamcmd.on('error', (error) => {
      finish({reachable: false, reason: (error.message || '').trim().split('\n').pop()});
    });

    steamcmd.on('close', () => {
      const apps = {};

      appIds.forEach((appId) => {
        apps[appId] = appBlock(stdout, appId);
      });

      if (!Object.values(apps).some((app) => app)) {
        finish({
          reachable: false,
          reason: `steamcmd returned no app info (session expired? run "steamcmd +login ${login}")`
        });
        return;
      }

      finish({reachable: true, apps});
    });
  });

// -----------------------------------------------------------------------------

export const readSteamStore = async (login, appIds) => {
  if (!login) {
    return {reachable: false, reason: 'no "publish.steam.login" in fox.config.json'};
  }

  if (!shell.which('steamcmd')) {
    return {reachable: false, reason: 'steamcmd not found — https://developer.valvesoftware.com/wiki/SteamCMD'};
  }

  return await runSteamcmd(login, [...new Set(appIds.map(String))]);
};

// -----------------------------------------------------------------------------
// What the store serves for one (app, branch, depot) triple.

export const storeSlot = (app, branch, depotId) => {
  if (!app) {
    return null;
  }

  const depots = app.depots || {};
  const head = (depots.branches || {})[branch];
  const manifest = ((depots[depotId] || {}).manifests || {})[branch];

  if (!head && !manifest) {
    return null;
  }

  return {
    branch,
    buildId: head && head.buildid,
    updatedAt: head && head.timeupdated ? new Date(Number(head.timeupdated) * 1000) : null,
    manifest: manifest && manifest.gid,
    size: manifest && Number(manifest.size)
  };
};

// -----------------------------------------------------------------------------
// The local half of the join: what the last `fox publish` from this machine
// uploaded. steamcmd leaves one `.vdf` per depot (the manifest it created) and
// one log per app (the BuildID it was assigned), both overwritten on every run —
// so this describes the LAST upload and nothing before it.

const readAppLog = (outputDir, appId) => {
  const logPath = path.join(outputDir, `app_build_${appId}.log`);

  if (!fs.existsSync(logPath)) {
    return {};
  }

  const text = fs.readFileSync(logPath, 'utf8');
  const build = text.match(/BuildID (\d+)/);
  const stamp = text.match(/^\[([^\]]+)\]/);

  return {
    buildId: build && build[1],
    uploadedAt: stamp ? new Date(stamp[1].replace(' ', 'T')) : null
  };
};

const readDepotVdf = (outputDir, depotId) => {
  const vdfPath = path.join(outputDir, `depot_build_${depotId}.vdf`);

  if (!fs.existsSync(vdfPath)) {
    return {};
  }

  const parsed = parseVdf(fs.readFileSync(vdfPath, 'utf8')).depotbuild || {};

  return {manifest: parsed.manifest, appId: parsed.appid};
};

// The content path proves WHICH folder those bytes came from: the same depot ids
// are uploaded from `export/<env>/steam`, and a stale log from another env would
// otherwise be read as a match.
const readDepotContentRoot = (outputDir, depotId) => {
  const logPath = path.join(outputDir, `depot_build_${depotId}.log`);

  if (!fs.existsSync(logPath)) {
    return null;
  }

  const found = fs.readFileSync(logPath, 'utf8').match(/content path is "([^"]+)"/);

  return found ? found[1] : null;
};

export const readLastUpload = (appId, depotIds) => {
  const outputDir = path.resolve(process.cwd(), STEAM_OUTPUT_DIR);
  const app = readAppLog(outputDir, appId);
  const depots = {};

  depotIds.forEach((depotId) => {
    const {manifest, appId: loggedApp} = readDepotVdf(outputDir, depotId);

    depots[depotId] = {
      // A depot id belongs to one app, but the guard costs nothing and a wrong
      // join here would be invisible.
      manifest: !loggedApp || String(loggedApp) === String(appId) ? manifest : null,
      contentPath: readDepotContentRoot(outputDir, depotId)
    };
  });

  return {...app, depots};
};
