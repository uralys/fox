// -----------------------------------------------------------------------------
// `fox ls:itch` answers the itch half of the same question: is the build live on
// the page the one sitting in my export folder?
//
// The confrontation is on the VERSION, not on a hash: butler stores a build as a
// diff against its parent and never exposes the bytes it reassembled, so there is
// no equivalent of the Deck's PCK sha here. What it does expose is the
// `userVersion` `fox publish` stamped on the push — which is itself read from the
// payload — so comparing it against the version baked in the local folder still
// says whether the page carries these exact bytes' release.
//
// itch is optional by design: no butler, or a butler that cannot reach the API,
// simply means the local half is reported on its own. It is a listing, never a
// gate.

import path from 'path';
import shell from 'shelljs';
import {execFile} from 'child_process';

// -----------------------------------------------------------------------------

import {createLogger, foxLogger} from '../logger.js';
import {envChip, targetChip} from '../bundler/export.js';
import {formatStamp} from '../bundler/baked-bundle.js';
import {exportRoot, publishableEnvs, readPublishConfig} from '../bundler/publish-config.js';
import {readLocalSlots, localLine, warnOnLocalVersions} from './local.js';

// -----------------------------------------------------------------------------

const localLogger = createLogger({name: 'Local', color: 'green'});
const itchLogger = createLogger({name: 'itch', color: 'red'});

const COMPLETED = 'completed';

// -----------------------------------------------------------------------------
// `butler status` prints one JSON object per line and only the last one is the
// result; the others are progress and log records that a plain JSON.parse of the
// whole output would choke on.

const parseButler = (stdout) => {
  const result = stdout
    .split('\n')
    .map((line) => {
      try {
        return JSON.parse(line);
      } catch (e) {
        return null;
      }
    })
    .filter((record) => record && record.type === 'result' && record.value)
    .pop();

  if (!result || !Array.isArray(result.value.channels)) {
    return null;
  }

  const channels = {};

  result.value.channels.forEach(({name, head, uploadId}) => {
    channels[name] = {
      uploadId,
      buildId: head && head.id,
      state: head && head.state,
      version: head && head.userVersion,
      updatedAt: head && head.updatedAt ? new Date(head.updatedAt) : null
    };
  });

  return channels;
};

const readItch = (page) =>
  new Promise((resolve) => {
    if (!shell.which('butler')) {
      resolve({reachable: false, reason: 'butler not found — https://itch.io/docs/butler/installing.html'});
      return;
    }

    execFile('butler', ['status', page, '--json'], {maxBuffer: 1024 * 1024}, (error, stdout) => {
      if (error) {
        resolve({reachable: false, reason: (error.message || '').trim().split('\n').pop()});
        return;
      }

      const channels = parseButler(stdout);

      if (!channels) {
        resolve({reachable: false, reason: `butler returned no channel for ${page}`});
        return;
      }

      resolve({reachable: true, channels});
    });
  });

// -----------------------------------------------------------------------------

const remoteLine = (remote) => {
  if (!remote) {
    return 'never pushed';
  }

  const state = remote.state === COMPLETED ? '' : ` — ${remote.state || 'state unknown'}`;
  const pushed = remote.updatedAt ? ` — pushed ${formatStamp(remote.updatedAt)}` : '';

  return `build #${remote.buildId} — ${remote.version || 'version unknown'}${state}${pushed}`;
};

// -----------------------------------------------------------------------------

const reportTarget = ({label, page, contentRoot, channels, itch, projectVersion}) => {
  const absoluteContentRoot = path.resolve(process.cwd(), contentRoot);
  const local = readLocalSlots(absoluteContentRoot, channels);

  localLogger.reset();
  localLogger.log(`${targetChip('itch')} ${envChip(label)} — ${page} — ${contentRoot}/`);

  const details = {};

  local.forEach((channel) => {
    const line = `${channel.folder}/ ${localLine(channel)}`;

    details[channel.slot] = itch && itch.reachable
      ? `${line}\n  live: ${remoteLine(itch.channels[channel.slot])}`
      : line;
  });

  localLogger.data(details);

  // -------- verdicts

  warnOnLocalVersions(localLogger, local, projectVersion, label);

  if (!itch || !itch.reachable) {
    return;
  }

  const pushed = [];
  let diverged = false;

  local.forEach((channel) => {
    const remote = itch.channels[channel.slot];

    if (!remote) {
      itchLogger.warn(`${label}: channel "${channel.slot}" has never been pushed`);
      diverged = true;
      return;
    }

    if (remote.state !== COMPLETED) {
      itchLogger.warn(`${label}: channel "${channel.slot}" is ${remote.state || 'in an unknown state'} on itch`);
      diverged = true;
    }

    if (!channel.version) {
      return;
    }

    if (remote.version !== channel.version) {
      itchLogger.warn(
        `${label}: channel "${channel.slot}" is live in ${remote.version || '?'} while ${channel.folder}/ holds ${channel.version}`
      );
      diverged = true;
      return;
    }

    pushed.push(channel.slot);
  });

  // A channel configured nowhere locally still lives on the page, and it is the
  // one an old push leaves behind — worth naming, never worth failing on.
  Object.keys(itch.channels)
    .filter((name) => !local.some(({slot}) => slot === name))
    .forEach((name) => {
      itchLogger.log(`${label}: channel "${name}" is live on itch but not declared in fox.config.json`);
    });

  if (!diverged && pushed.length === local.length && local.length) {
    itchLogger.success(`${label}: ${page} is live in ${local[0].version} on all ${local.length} channels`);
  }
};

// -----------------------------------------------------------------------------

const lsItch = async (settings, {projectVersion}) => {
  const {publish} = settings;

  const targets = publishableEnvs({publish}, 'itch')
    .map((env) => ({label: env, itch: readPublishConfig({publish}, 'itch', env), env}))
    .filter(({itch}) => itch && itch.user && itch.game && !String(itch.user).startsWith('<'));

  if (!targets.length) {
    foxLogger.error('No itch.io game configured — add "publish.itch.envs" to fox.config.json');
    return false;
  }

  // One page per (user, game) pair, so one butler call per page even when several
  // envs push their own channels to it.
  const pages = [...new Set(targets.map(({itch}) => `${itch.user}/${itch.game}`))];
  const statuses = {};

  for (const page of pages) {
    statuses[page] = await readItch(page);

    if (!statuses[page].reachable) {
      // Not an error: the listing is still worth printing without it.
      itchLogger.log(`${page} not read — local builds only (${statuses[page].reason})`);
    }
  }

  targets.forEach(({label, itch, env}) => {
    const page = `${itch.user}/${itch.game}`;

    reportTarget({
      label,
      page,
      contentRoot: itch.contentRoot || exportRoot(env, 'itch'),
      channels: itch.channels,
      itch: statuses[page],
      projectVersion
    });
  });

  return true;
};

export default lsItch;
