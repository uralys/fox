// -----------------------------------------------------------------------------
// fox upgrade: pin the game to a released version of the addon
// -----------------------------------------------------------------------------
// Replaces `addons/fox` with the tree of a published tag, WHOLE: the folder is
// deleted before the new one lands, so a file dropped between two versions
// leaves with them. That is the one thing neither the Godot Asset Library nor a
// manual copy does, and it is why this command exists.
//
// The tarball of the tag is used rather than the release zip: `tar -xzf` reads
// it on macOS, Linux and Windows alike, where unzipping needs a tool that is
// not everywhere.
// -----------------------------------------------------------------------------

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

import pkg from '../package.json' with { type: 'json' };
import { CONFIG_FILE, readPinnedVersion, writePinnedVersion } from './fox-config.js';
import { ignoreMount } from './ignore-mount.js';
import { reimportProject } from './import-assets.js';
import { isLinkedCli, pinCli } from './install-cli.js';
import { fetchLatestTag } from './latest-release.js';
import { upgradeLogger } from './logger.js';
import { ADDON_MOUNT, describeMount, LINKED, MISSING, PINNED, readMountedVersion } from './resolve-fox-mount.js';

// -----------------------------------------------------------------------------

const REPOSITORY = 'uralys/fox';
const TARBALL = (tag) => `https://github.com/${REPOSITORY}/archive/refs/tags/${tag}.tar.gz`;

// Tags carry the `v`, the release title and `plugin.cfg` do not: both spellings
// are accepted on the command line so nobody has to remember which is which.
const asTag = (version) => (version.startsWith('v') ? version : `v${version}`);
const asVersion = (tag) => tag.replace(/^v/, '');

// -----------------------------------------------------------------------------

// A missing mount is a RESTORE, not an upgrade: a fresh clone of a game whose
// runtime is ignored holds no addon, and the version it is owed is the one it
// declares, not whatever came out last week. Anywhere else `upgrade` keeps
// meaning upgrade, so the release notice telling a game to run it stays true.
const resolveTargetTag = async (requested, kind, projectRoot) => {
  if (requested) {
    return asTag(requested);
  }

  if (kind === MISSING) {
    const pinned = readPinnedVersion(projectRoot);

    if (pinned) {
      upgradeLogger.log(`Restoring the ${pinned} pinned in ${CONFIG_FILE}`);
      return asTag(pinned);
    }
  }

  upgradeLogger.log('Reading the latest release');

  // No timeout here, unlike the end of command notice: this one was asked for,
  // and it caches what it reads, so the next commands stay quiet about a
  // release that was just pinned.
  return await fetchLatestTag();
};

// -----------------------------------------------------------------------------

// The tarball holds the whole repository under a single generated folder, so
// the addon is picked out of the extraction rather than filtered during it:
// the `--strip-components` and wildcard flags differ between GNU tar and the
// bsdtar shipped by macOS and Windows.
const downloadAddon = async (tag, workDir) => {
  const archive = path.join(workDir, 'fox.tar.gz');

  upgradeLogger.log(`Downloading ${tag}`);

  const response = await fetch(TARBALL(tag), { redirect: 'follow' });

  if (!response.ok) {
    throw new Error(`GitHub answered ${response.status} for ${tag}`);
  }

  fs.writeFileSync(archive, Buffer.from(await response.arrayBuffer()));

  const extracted = path.join(workDir, 'extracted');
  fs.mkdirSync(extracted);
  execFileSync('tar', ['-xzf', archive, '-C', extracted]);

  const [root] = fs.readdirSync(extracted);
  const addon = path.join(extracted, root, ADDON_MOUNT);

  if (!fs.existsSync(path.join(addon, 'plugin.cfg'))) {
    throw new Error(`${tag} holds no ${ADDON_MOUNT}: it predates the addon layout`);
  }

  return addon;
};

// -----------------------------------------------------------------------------

// What a game keeps of an upgrade once the mount itself is ignored: the version
// in `core.fox`, and the ignore line that lets it be ignored at all. Both are
// idempotent, so they are run on every successful pinning rather than guessed
// at, and `--no-gitignore` leaves a game that tracks its mount on purpose alone.
const recordPin = (version, projectRoot, params) => {
  writePinnedVersion(version, projectRoot, upgradeLogger);

  if (!params.includes('--no-gitignore')) {
    ignoreMount(projectRoot, upgradeLogger);
  }
};

// -----------------------------------------------------------------------------

const upgrade = async (params = []) => {
  const projectRoot = process.cwd();
  const requested = params.find((param) => !param.startsWith('-'));
  const confirmed = params.includes('--yes');

  const { kind, mountPath, target } = describeMount(projectRoot);

  if (kind === LINKED && !confirmed) {
    upgradeLogger.error(`${ADDON_MOUNT} is linked to ${target}`);
    upgradeLogger.log('Upgrading replaces that link with a pinned copy of a released version.');
    upgradeLogger.log('Run `fox upgrade --yes` to do it, or keep following your checkout.');
    return false;
  }

  const installed = kind === MISSING ? null : readMountedVersion(projectRoot);
  const workDir = fs.mkdtempSync(path.join(os.tmpdir(), 'fox-upgrade-'));

  try {
    const tag = await resolveTargetTag(requested, kind, projectRoot);
    const version = asVersion(tag);

    // Fox ships in two halves and both are upgraded: the runtime under
    // `addons/fox`, and the global `fox` executable. A symlinked CLI runs the
    // checkout whatever the mount says, so it is reported beside the mount and
    // it is upgraded even when the addon has nothing to do.
    const skipCli = params.includes('--no-cli');
    const cliPinned = skipCli || (!isLinkedCli() && pkg.version === version);

    upgradeLogger.data({
      mount: kind,
      installed: kind === LINKED ? `${installed ?? 'unknown'} (linked, not a release)` : (installed ?? 'none'),
      pinned: readPinnedVersion(projectRoot) ?? 'none',
      cli: isLinkedCli() ? `${pkg.version} (symlinked, not a release)` : pkg.version,
      target: version,
    });

    const addonPinned = kind === PINNED && installed === version;

    if (addonPinned && cliPinned) {
      recordPin(version, projectRoot, params);
      upgradeLogger.done(`already on ${version}`);
      return true;
    }

    // Nothing to download and nothing to reimport: the game already holds the
    // tree of that tag, only the executable was left behind.
    if (addonPinned) {
      upgradeLogger.log(`${ADDON_MOUNT} is already ${version}, upgrading the CLI alone`);
      recordPin(version, projectRoot, params);
      pinCli(tag, upgradeLogger);
      upgradeLogger.done(`fox is now ${version}`);
      return true;
    }

    const addon = await downloadAddon(tag, workDir);

    // Removed whole rather than copied over: a file that left the addon between
    // the two versions would otherwise survive in the game forever.
    if (kind === LINKED) {
      fs.unlinkSync(mountPath);
    } else if (kind !== MISSING) {
      fs.rmSync(mountPath, { recursive: true, force: true });
    }

    fs.mkdirSync(path.dirname(mountPath), { recursive: true });
    fs.cpSync(addon, mountPath, { recursive: true });

    upgradeLogger.success(`${ADDON_MOUNT} is now ${version}`);

    recordPin(version, projectRoot, params);

    // The executable follows the runtime it was pinned with, so a game is not
    // frozen against a runtime regression while still riding a live CLI.
    if (!skipCli) {
      pinCli(tag, upgradeLogger);
    }

    if (params.includes('--no-import')) {
      upgradeLogger.done('run `fox import` to reimport the addon');
      return true;
    }

    return await reimportProject(projectRoot, upgradeLogger);
  } catch (error) {
    upgradeLogger.error(error.message);
    return false;
  } finally {
    fs.rmSync(workDir, { recursive: true, force: true });
  }
};

// -----------------------------------------------------------------------------

export default upgrade;
