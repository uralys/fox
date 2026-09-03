// -----------------------------------------------------------------------------
// `fox ls` answers one question: is the build installed on the Steam Deck the
// one sitting in my export folder?
//
// Neither half can answer it alone. Steam knows a BuildID and a branch but
// nothing about what those bytes contain; the export folder knows a version but
// not whether Steam ever shipped it. So both sides are read and confronted on
// the PCK — the payload itself, identical across platforms, unlike the
// executable.
//
// The Deck is optional by design: unreachable simply means the local half is
// reported on its own. It is a listing, never a gate.

import fs from 'fs';
import path from 'path';
import {execFile} from 'child_process';

// -----------------------------------------------------------------------------

import {createLogger, foxLogger} from './logger.js';
import {envChip} from './bundler/export.js';
import {readProjectVersion} from './bundler/tag.js';
import {PUBLISH_TARGETS} from './bundler/publish.js';
import {readBakedBundle, newestMtime, formatStamp, findPck, sha256} from './bundler/baked-bundle.js';

// -----------------------------------------------------------------------------

const localLogger = createLogger({name: 'Local', color: 'green'});
const deckLogger = createLogger({name: 'SteamDeck', color: 'magenta'});

const DEFAULT_HOST = 'deck@steamdeck.local';
const DEFAULT_TIMEOUT = 8;

// The Deck depot: the only platform folder a Linux handheld can be compared to.
const DECK_PLATFORM = 'linux';

const SHORT_SHA = 12;

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
      current = {appId: value};
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
      {maxBuffer: 1024 * 1024},
      (error, stdout) => {
        if (error) {
          resolve({reachable: false, reason: (error.message || '').trim().split('\n').pop()});
          return;
        }

        resolve({reachable: true, apps: parseRemote(stdout)});
      }
    );
  });

// -----------------------------------------------------------------------------

const readLocalDepots = (contentRoot, depots) =>
  Object.entries(depots).map(([depotId, folder]) => {
    const depotPath = path.resolve(contentRoot, folder);

    if (!fs.existsSync(depotPath)) {
      return {depotId, folder, missing: true};
    }

    const files = fs.readdirSync(depotPath).filter((file) => !file.startsWith('.'));

    if (!files.length) {
      return {depotId, folder, empty: true};
    }

    const {version, env} = readBakedBundle(depotPath, files);
    const pck = findPck(depotPath, files);

    return {
      depotId,
      folder,
      version,
      env,
      pck,
      archive: files.find((file) => ARCHIVE_EXTENSIONS.some((extension) => file.endsWith(extension))),
      sha: pck ? sha256(path.join(depotPath, pck)) : null,
      exportedAt: newestMtime(depotPath, files)
    };
  });

// A notarized macOS export ships as an archive: the payload is in there, but
// saying "version unknown" would read as a broken export rather than as a
// format this listing does not open.
const ARCHIVE_EXTENSIONS = ['.zip', '.dmg'];

const localLine = (depot) => {
  if (depot.missing) {
    return 'never exported';
  }

  if (depot.empty) {
    return 'empty folder';
  }

  if (!depot.version && depot.archive) {
    return `${depot.archive} — archive not read — exported ${formatStamp(depot.exportedAt)}`;
  }

  const chip = depot.env ? ` ${envChip(depot.env)}` : '';
  const short = depot.sha ? ` ${depot.sha.slice(0, SHORT_SHA)}` : '';

  return `${depot.version || 'version unknown'}${chip} — exported ${formatStamp(depot.exportedAt)}${short}`;
};

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

const reportTarget = ({label, appId, contentRoot, depots, deck, projectVersion}) => {
  const absoluteContentRoot = path.resolve(process.cwd(), contentRoot);
  const local = readLocalDepots(absoluteContentRoot, depots);

  localLogger.reset();
  localLogger.log(`${label} — appId ${appId} — ${contentRoot}/`);

  const details = {};
  local.forEach((depot) => {
    details[depot.folder] = localLine(depot);
  });

  if (deck && deck.reachable) {
    const app = deck.apps[appId];
    details['steam deck'] = app && app.installed === 'yes' ? deckLine(app) : 'not installed';
  }

  localLogger.data(details);

  // -------- verdicts

  const versions = [...new Set(local.filter((depot) => depot.version).map(({version}) => version))];

  if (versions.length > 1) {
    localLogger.warn(`depots disagree on the version: ${versions.join(', ')}`);
  } else if (versions.length === 1 && versions[0] !== projectVersion) {
    localLogger.warn(`export is ${versions[0]} while project.godot is ${projectVersion}`);
  }

  if (!deck || !deck.reachable) {
    return;
  }

  const app = deck.apps[appId];

  if (!app || app.installed !== 'yes') {
    return;
  }

  if (app.wantedBranch !== app.mountedBranch) {
    deckLogger.warn(
      `${label}: branch "${app.wantedBranch || 'default'}" requested but "${app.mountedBranch || 'default'}" is mounted — restart Steam`
    );
  }

  if (app.targetBuildId && app.targetBuildId !== app.buildid) {
    deckLogger.warn(`${label}: build ${app.buildid} installed, ${app.targetBuildId} available — update pending`);
  }

  const reference = local.find(({folder}) => folder === DECK_PLATFORM);

  if (!reference || !reference.sha || !app.sha) {
    return;
  }

  if (reference.sha === app.sha) {
    deckLogger.success(`${label}: the deck runs the exact ${contentRoot}/${DECK_PLATFORM} payload (${app.version})`);
    return;
  }

  deckLogger.warn(
    `${label}: the deck PCK is NOT the local one — deck ${app.version || '?'} ${app.sha.slice(0, SHORT_SHA)}, local ${reference.version || '?'} ${reference.sha.slice(0, SHORT_SHA)}`
  );
};

// -----------------------------------------------------------------------------

const ls = async (settings) => {
  const {core, config, publish} = settings;

  const targets = PUBLISH_TARGETS.map((target) => ({...target, steam: publish && publish[target.key]})).filter(
    ({steam}) => steam && steam.appId && !String(steam.appId).startsWith('<')
  );

  if (!targets.length) {
    foxLogger.error('No Steam app configured — add "publish.steam" or "publish.steamDemo" to fox.config.json');
    return;
  }

  const projectVersion = readProjectVersion();

  foxLogger.log(`${core.title} — project.godot is ${projectVersion}`);

  const host = (config && config.host) || DEFAULT_HOST;
  const timeout = (config && config.timeout) || DEFAULT_TIMEOUT;

  const deck = await readDeck(host, timeout, targets.map(({steam}) => steam.appId));

  if (!deck.reachable) {
    // Not an error: the listing is still worth printing without it.
    deckLogger.log(`${host} not connected — local builds only${deck.reason ? ` (${deck.reason})` : ''}`);
  }

  targets.forEach(({label, steam}) => {
    reportTarget({
      label,
      appId: steam.appId,
      contentRoot: steam.contentRoot,
      depots: steam.depots,
      deck,
      projectVersion
    });
  });

  return true;
};

export default ls;
