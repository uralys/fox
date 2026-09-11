// -----------------------------------------------------------------------------
// `fox ls:steam` answers one question: are the bytes in my export folder the
// ones Steam serves — and the ones the Deck runs?
//
// No half can answer it alone. Steam knows a BuildID and a manifest but nothing
// about what those bytes contain; the export folder knows a version but not
// whether Steam ever shipped it; the Deck knows what it downloaded but not what
// the branch points at now. So three sides are read and joined on the only
// identifier each pair shares: the MANIFEST between the store and the last
// upload, the PCK sha between the Deck and the export folder.
//
// Store and Deck are both optional by design: unreachable simply means the local
// half is reported on its own. It is a listing, never a gate.

import { execFile } from 'node:child_process';
import path from 'node:path';

// -----------------------------------------------------------------------------

import { formatStamp } from '../bundler/baked-bundle.js';
import { envChip, targetChip } from '../bundler/export.js';
import { exportRoot, publishableEnvs, readPublishConfig } from '../bundler/publish-config.js';
import { createLogger, foxLogger } from '../logger.js';
import { localLine, localVersions, readLocalSlots, SHORT_SHA, warnOnLocalVersions } from './local.js';
import { DEFAULT_BRANCH, readLastUpload, readSteamStore, storeSlot } from './steam-store.js';

// -----------------------------------------------------------------------------

const localLogger = createLogger({ name: 'Local', color: 'green' });
const deckLogger = createLogger({ name: 'SteamDeck', color: 'magenta' });
const steamLogger = createLogger({ name: 'Steam', color: 'magenta' });

const DEFAULT_HOST = 'deck@steamdeck.local';
const DEFAULT_TIMEOUT = 8;

// The Deck depot: the only platform folder a Linux handheld can be compared to.
const DECK_PLATFORM = 'linux';

// -----------------------------------------------------------------------------
// Remote reading, in shell, because the payload stays on the Deck: pulling a
// 40MB PCK over SSH on every listing to reuse the JS reader would cost seconds
// for a value a grep answers in place. It mirrors `readBakedValue` on the one
// key it needs — the `[^[:print:]]` guard after the key is what keeps
// `bundle/versionCode` from being read as `bundle/version`.

const remoteScript = (appIds) => `
STEAM="$HOME/.local/share/Steam/steamapps"

for APPID in ${appIds.join(' ')}; do
  echo "app $APPID"
  ACF="$STEAM/appmanifest_$APPID.acf"

  if [ ! -f "$ACF" ]; then
    echo "installed no"
    continue
  fi

  echo "installed yes"

  field() {
    sed -n "s/.*\\"$1\\"[[:space:]]*\\"\\([^\\"]*\\)\\".*/\\1/p" "$ACF"
  }

  echo "buildid $(field buildid | head -1)"
  echo "targetBuildId $(field TargetBuildID | head -1)"
  echo "stateFlags $(field StateFlags | head -1)"
  echo "lastUpdated $(field LastUpdated | head -1)"

  # "BetaKey" appears twice: UserConfig (the branch asked for) then
  # MountedConfig (the branch actually mounted). They can disagree.
  echo "wantedBranch $(field BetaKey | head -1)"
  echo "mountedBranch $(field BetaKey | tail -1)"

  GAME="$STEAM/common/$(field installdir | head -1)"
  PCK=$(ls "$GAME"/*.pck 2>/dev/null | head -1)

  if [ -z "$PCK" ]; then
    echo "pck none"
    continue
  fi

  echo "pck $(basename "$PCK")"
  echo "sha $(sha256sum "$PCK" | cut -d' ' -f1)"
  echo "version $(LC_ALL=C grep -aoE 'bundle/version[^[:print:]]+[[:print:]]+' "$PCK" | head -1 | sed 's|bundle/version||' | tr -cd '[:print:]')"
  echo "env $(LC_ALL=C grep -aoE 'bundle/env[^[:print:]]+[[:print:]]+' "$PCK" | head -1 | sed 's|bundle/env||' | tr -cd '[:print:]')"
done
`;

const parseRemote = (stdout) => {
  const apps = {};
  let current = null;

  stdout.split('\n').forEach((line) => {
    const [key, ...rest] = line.trim().split(' ');
    const value = rest.join(' ').trim();

    if (!key) {
      return;
    }

    if (key === 'app') {
      current = { appId: value };
      apps[value] = current;
      return;
    }

    if (current) {
      current[key] = value;
    }
  });

  return apps;
};

const readDeck = (host, timeout, appIds) =>
  new Promise((resolve) => {
    execFile(
      'ssh',
      ['-o', 'BatchMode=yes', '-o', `ConnectTimeout=${timeout}`, host, remoteScript(appIds)],
      { maxBuffer: 1024 * 1024 },
      (error, stdout) => {
        if (error) {
          resolve({ reachable: false, reason: (error.message || '').trim().split('\n').pop() });
          return;
        }

        resolve({ reachable: true, apps: parseRemote(stdout) });
      },
    );
  });

// -----------------------------------------------------------------------------
// StateFlags is a bitfield; 4 alone means "fully installed, nothing pending".
// Anything else is worth showing raw rather than interpreted, because the
// interesting cases (update required, update running) are exactly the ones a
// wrong guess would hide.

const FULLY_INSTALLED = '4';

const deckLine = (app) => {
  const build = app.buildid || 'unknown';
  const pending = app.targetBuildId && app.targetBuildId !== app.buildid;
  const branch = app.mountedBranch || 'default';
  const chip = app.env ? ` ${envChip(app.env)}` : '';

  const flags = app.stateFlags === FULLY_INSTALLED ? '' : ` — stateFlags ${app.stateFlags}`;
  const target = pending ? ` — update pending to ${app.targetBuildId}` : '';
  const short = app.sha ? ` ${app.sha.slice(0, SHORT_SHA)}` : '';

  return `build ${build} on "${branch}" — ${app.version || 'version unknown'}${chip}${short}${target}${flags}`;
};

// -----------------------------------------------------------------------------
// What the store serves, in one line per depot.

const storeLine = (remote) => {
  if (!remote) {
    return 'never shipped on this branch';
  }

  const build = remote.buildId ? `build ${remote.buildId}` : 'build unknown';
  const manifest = remote.manifest ? ` — manifest ${remote.manifest}` : '';
  const updated = remote.updatedAt ? ` — set live ${formatStamp(remote.updatedAt)}` : '';

  return `${build} on "${remote.branch}"${manifest}${updated}`;
};

// -----------------------------------------------------------------------------
// What the PUBLIC branch serves, when the project publishes to another one.
//
// A build set live on "staging" is invisible to players: the branch that ships
// the demo is always the default one. The listing would otherwise report a green
// "is live" that only a developer with the beta key can see, so the public
// branch is read on its own and compared to the branch just reported — depot by
// depot on the MANIFEST, the only identifier that proves identical bytes.

const publicVerdict = ({ label, depots, branch, app, local }) => {
  if (branch === DEFAULT_BRANCH) {
    return;
  }

  const depotIds = Object.keys(depots);
  const slots = depotIds.map((depotId) => storeSlot(app, DEFAULT_BRANCH, depotId));
  const head = slots.find((slot) => slot);

  if (!head) {
    steamLogger.warn(`${label}: branch "${DEFAULT_BRANCH}" has never been set live — no player can see this app yet`);
    return;
  }

  const sameBytes = depotIds.every((depotId, index) => {
    const live = storeSlot(app, branch, depotId);

    return live?.manifest && slots[index]?.manifest === live.manifest;
  });

  const versions = localVersions(local);
  const version = versions.length === 1 ? versions[0] : null;
  const build = head.buildId ? ` (build ${head.buildId})` : '';

  if (sameBytes) {
    steamLogger.success(
      `${label}: branch "${DEFAULT_BRANCH}" serves the same bytes${build} — players have${version ? ` ${version}` : ' it'}`,
    );
    return;
  }

  const updated = head.updatedAt ? `, set live ${formatStamp(head.updatedAt)}` : '';

  steamLogger.warn(
    `${label}: players are still on branch "${DEFAULT_BRANCH}"${build}${updated} — "${branch}" is NOT what the store hands out`,
  );
};

// -----------------------------------------------------------------------------
// The store verdict: does the branch serve the manifests this machine last
// uploaded? Anything that breaks the join is named rather than guessed at — a
// silent "not live" would be indistinguishable from a listing that simply cannot
// tell.

const reportStore = ({ label, appId, contentRoot, depots, branch, app, local }) => {
  const upload = readLastUpload(appId, Object.keys(depots));
  const absoluteContentRoot = path.resolve(process.cwd(), contentRoot);
  const versions = localVersions(local);

  let diverged = false;
  const live = [];

  Object.keys(depots).forEach((depotId) => {
    const remote = storeSlot(app, branch, depotId);
    const uploaded = upload.depots[depotId] || {};

    if (!remote) {
      steamLogger.warn(`${label}: depot ${depotId} is not served on branch "${branch}"`);
      diverged = true;
      return;
    }

    if (!uploaded.manifest) {
      // Nothing to join on: another machine published, or _build was wiped.
      steamLogger.log(
        `${label}: depot ${depotId} serves manifest ${remote.manifest} — no local upload record to compare it to`,
      );
      diverged = true;
      return;
    }

    if (uploaded.contentPath && !uploaded.contentPath.startsWith(absoluteContentRoot)) {
      steamLogger.warn(
        `${label}: the last upload of depot ${depotId} came from ${uploaded.contentPath}, not from ${contentRoot}/`,
      );
      diverged = true;
      return;
    }

    if (remote.manifest !== uploaded.manifest) {
      steamLogger.warn(
        `${label}: depot ${depotId} serves manifest ${remote.manifest} while the last upload created ${uploaded.manifest}`,
      );
      diverged = true;
      return;
    }

    live.push(depotId);
  });

  if (upload.buildId && app && storeSlot(app, branch, Object.keys(depots)[0])) {
    const head = storeSlot(app, branch, Object.keys(depots)[0]);

    if (head.buildId && head.buildId !== upload.buildId) {
      steamLogger.log(
        `${label}: branch "${branch}" is on build ${head.buildId}, the last upload from here was ${upload.buildId}`,
      );
    }
  }

  if (diverged || live.length !== Object.keys(depots).length || !live.length) {
    return;
  }

  const version = versions.length === 1 ? versions[0] : null;
  const build = upload.buildId ? ` (build ${upload.buildId})` : '';

  steamLogger.success(
    `${label}: appId ${appId} is live${version ? ` in ${version}` : ''} on branch "${branch}" on all ${live.length} depots${build}`,
  );
};

// -----------------------------------------------------------------------------

const reportTarget = ({ label, appId, contentRoot, depots, branch, store, deck, projectVersion }) => {
  const absoluteContentRoot = path.resolve(process.cwd(), contentRoot);
  const local = readLocalSlots(absoluteContentRoot, depots);
  const app = store?.reachable ? store.apps[appId] : null;

  localLogger.reset();
  localLogger.log(`${targetChip('steam')} ${envChip(label)} — appId ${appId} — ${contentRoot}/`);

  const details = {};
  local.forEach((depot) => {
    const line = localLine(depot);

    if (!app) {
      details[depot.folder] = line;
      return;
    }

    const live = `\n  live: ${storeLine(storeSlot(app, branch, depot.slot))}`;
    const shared =
      branch === DEFAULT_BRANCH
        ? ''
        : `\n  ${DEFAULT_BRANCH}: ${storeLine(storeSlot(app, DEFAULT_BRANCH, depot.slot))}`;

    details[depot.folder] = `${line}${live}${shared}`;
  });

  if (deck?.reachable) {
    const installed = deck.apps[appId];
    details['steam deck'] = installed && installed.installed === 'yes' ? deckLine(installed) : 'not installed';
  }

  localLogger.data(details);

  // -------- verdicts

  warnOnLocalVersions(localLogger, local, projectVersion, label);

  if (app) {
    steamLogger.reset();
    reportStore({ label, appId, contentRoot, depots, branch, app, local });
    publicVerdict({ label, depots, branch, app, local });
  }

  if (!deck?.reachable) {
    return;
  }

  const installed = deck.apps[appId];

  if (installed?.installed !== 'yes') {
    return;
  }

  if (installed.wantedBranch !== installed.mountedBranch) {
    deckLogger.warn(
      `${label}: branch "${installed.wantedBranch || 'default'}" requested but "${installed.mountedBranch || 'default'}" is mounted — restart Steam`,
    );
  }

  if (installed.targetBuildId && installed.targetBuildId !== installed.buildid) {
    deckLogger.warn(
      `${label}: build ${installed.buildid} installed, ${installed.targetBuildId} available — update pending`,
    );
  }

  const reference = local.find(({ folder }) => folder === DECK_PLATFORM);

  if (!reference?.sha || !installed.sha) {
    return;
  }

  if (reference.sha === installed.sha) {
    deckLogger.success(
      `${label}: the deck runs the exact ${contentRoot}/${DECK_PLATFORM} payload (${installed.version})`,
    );
    return;
  }

  deckLogger.warn(
    `${label}: the deck PCK is NOT the local one — deck ${installed.version || '?'} ${installed.sha.slice(0, SHORT_SHA)}, local ${reference.version || '?'} ${reference.sha.slice(0, SHORT_SHA)}`,
  );
};

// -----------------------------------------------------------------------------

const lsSteam = async (settings, { projectVersion }) => {
  const { config, publish } = settings;

  // The deck only ever runs Steam builds, so this listing walks the Steam target's
  // envs — one entry per Steam app the project publishes.
  const targets = publishableEnvs({ publish }, 'steam')
    .map((env) => ({ label: env, steam: readPublishConfig({ publish }, 'steam', env), env }))
    .filter(({ steam }) => steam?.appId && !String(steam.appId).startsWith('<'));

  if (!targets.length) {
    foxLogger.error('No Steam app configured — add "publish.steam.envs" to fox.config.json');
    return false;
  }

  const host = config?.host || DEFAULT_HOST;
  const timeout = config?.timeout || DEFAULT_TIMEOUT;
  const appIds = targets.map(({ steam }) => steam.appId);

  // Both remote reads are independent and both are slow: the Deck waits on SSH,
  // steamcmd on a session and the appinfo cache.
  const [deck, store] = await Promise.all([
    readDeck(host, timeout, appIds),
    readSteamStore(publish.steam?.login, appIds),
  ]);

  if (!store.reachable) {
    // Not an error: the listing is still worth printing without it.
    steamLogger.log(`Steamworks not read — local builds only (${store.reason})`);
  }

  if (!deck.reachable) {
    deckLogger.log(`${host} not connected — local builds only${deck.reason ? ` (${deck.reason})` : ''}`);
  }

  targets.forEach(({ label, steam, env }) => {
    reportTarget({
      label,
      appId: steam.appId,
      contentRoot: steam.contentRoot || exportRoot(env, 'steam'),
      depots: steam.depots,
      branch: steam.branch || DEFAULT_BRANCH,
      store,
      deck,
      projectVersion,
    });
  });

  return true;
};

export default lsSteam;
