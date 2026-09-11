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

import { reimportProject } from './import-assets.js';
import { upgradeLogger } from './logger.js';
import { ADDON_MOUNT, describeMount, LINKED, MISSING, PINNED, readMountedVersion } from './resolve-fox-mount.js';

// -----------------------------------------------------------------------------

const REPOSITORY = 'uralys/fox';
const LATEST_RELEASE = `https://api.github.com/repos/${REPOSITORY}/releases/latest`;
const TARBALL = (tag) => `https://github.com/${REPOSITORY}/archive/refs/tags/${tag}.tar.gz`;

// Tags carry the `v`, the release title and `plugin.cfg` do not: both spellings
// are accepted on the command line so nobody has to remember which is which.
const asTag = (version) => (version.startsWith('v') ? version : `v${version}`);
const asVersion = (tag) => tag.replace(/^v/, '');

// -----------------------------------------------------------------------------

const resolveTargetTag = async (requested) => {
  if (requested) {
    return asTag(requested);
  }

  upgradeLogger.log('Reading the latest release');

  const response = await fetch(LATEST_RELEASE, {
    headers: { accept: 'application/vnd.github+json' },
  });

  if (!response.ok) {
    throw new Error(`GitHub answered ${response.status} for the latest release`);
  }

  return (await response.json()).tag_name;
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
    const tag = await resolveTargetTag(requested);
    const version = asVersion(tag);

    upgradeLogger.data({
      mount: kind,
      installed: kind === LINKED ? `${installed ?? 'unknown'} (linked, not a release)` : (installed ?? 'none'),
      target: version,
    });

    if (kind === PINNED && installed === version) {
      upgradeLogger.done(`already on ${version}`);
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
