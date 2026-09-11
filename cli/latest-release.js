// -----------------------------------------------------------------------------
// which release is out there, and whether the game is behind it
// -----------------------------------------------------------------------------
// `fox upgrade` exists, but nothing ever said it was worth running: a game can
// sit on an addon six versions old and every command looks perfectly healthy.
// So every command ends by comparing the mounted version with the latest
// release, and says one line when there is a newer one.
//
// That answer is CACHED, and the cache is the point of this module: asking
// GitHub on every `fox run:game` would add a network round trip to a command
// that otherwise touches nothing but the disk, and the rate limit on anonymous
// API calls is 60 per hour. One call every six hours, shared by every project
// on the machine, is enough to notice a release the day it lands.
//
// A failed check is cached too, under the tag it last knew. Without that, a
// machine offline for an afternoon would pay the timeout again on every single
// command.
// -----------------------------------------------------------------------------

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

import { colors, logBox } from './logger.js';
import { ADDON_MOUNT, describeMount, PINNED, readMountedVersion } from './resolve-fox-mount.js';

// -----------------------------------------------------------------------------

const REPOSITORY = 'uralys/fox';
const LATEST_RELEASE = `https://api.github.com/repos/${REPOSITORY}/releases/latest`;

const CACHE_FILE = path.join(os.homedir(), '.fox', 'latest-release.json');

const CHECK_INTERVAL = 6 * 60 * 60 * 1000;

// The check is a courtesy, never a reason for a command to hang: a GitHub that
// does not answer in two seconds is simply not answering today.
const FETCH_TIMEOUT = 2000;

// Set it to opt out entirely: CI runs pin their version on purpose and have no
// use for a line telling them to move.
const OPT_OUT = 'FOX_NO_UPGRADE_CHECK';

// -----------------------------------------------------------------------------

const readCache = () => {
  try {
    return JSON.parse(fs.readFileSync(CACHE_FILE, 'utf8'));
  } catch {
    return null;
  }
};

// -----------------------------------------------------------------------------

// `checkedAt` is written even when the tag is unknown: it is the back off, not
// the result.
const writeCache = (tag) => {
  try {
    fs.mkdirSync(path.dirname(CACHE_FILE), { recursive: true });
    fs.writeFileSync(CACHE_FILE, `${JSON.stringify({ tag, checkedAt: Date.now() }, null, 2)}\n`);
  } catch {
    // A read only home directory costs the cache, not the command.
  }
};

// -----------------------------------------------------------------------------

// The tag of the latest release, straight from GitHub. Throws, so `fox upgrade`
// can report why it could not resolve a target; the notice below swallows it.
const fetchLatestTag = async ({ timeout } = {}) => {
  const response = await fetch(LATEST_RELEASE, {
    headers: { accept: 'application/vnd.github+json' },
    signal: timeout ? AbortSignal.timeout(timeout) : undefined,
  });

  if (!response.ok) {
    throw new Error(`GitHub answered ${response.status} for the latest release`);
  }

  const { tag_name: tag } = await response.json();

  writeCache(tag);

  return tag;
};

// -----------------------------------------------------------------------------

const resolveLatestTag = async () => {
  const cache = readCache();

  if (cache && Date.now() - cache.checkedAt < CHECK_INTERVAL) {
    return cache.tag;
  }

  try {
    return await fetchLatestTag({ timeout: FETCH_TIMEOUT });
  } catch {
    writeCache(cache?.tag ?? null);
    return cache?.tag ?? null;
  }
};

// -----------------------------------------------------------------------------

// Numeric, field by field: comparing `"1.10.0"` to `"1.9.0"` as strings ranks
// the older one first, and the notice would then go quiet exactly when a minor
// version crosses ten.
const isNewer = (candidate, current) => {
  const parse = (version) => version.split('.').map((field) => Number.parseInt(field, 10) || 0);

  const left = parse(candidate);
  const right = parse(current);

  for (let i = 0; i < Math.max(left.length, right.length); i++) {
    const a = left[i] ?? 0;
    const b = right[i] ?? 0;

    if (a !== b) {
      return a > b;
    }
  }

  return false;
};

// -----------------------------------------------------------------------------

// Silent in every case but one: a pinned mount strictly behind a release. A
// linked mount follows a checkout and is SUPPOSED to differ from any release,
// and a missing one has nothing to compare.
const notifyLatestRelease = async (projectRoot = process.cwd()) => {
  if (process.env[OPT_OUT]) {
    return;
  }

  if (describeMount(projectRoot).kind !== PINNED) {
    return;
  }

  const installed = readMountedVersion(projectRoot);

  if (!installed) {
    return;
  }

  const tag = await resolveLatestTag();
  const latest = tag?.replace(/^v/, '');

  if (!latest || !isNewer(latest, installed)) {
    return;
  }

  logBox(
    [
      `${ADDON_MOUNT} is ${installed}, and ${latest} is out`,
      '',
      'run `fox upgrade` to pin it, or `fox upgrade --no-import` to reimport later',
    ],
    colors.yellow,
  );
};

// -----------------------------------------------------------------------------

export { fetchLatestTag, notifyLatestRelease };
