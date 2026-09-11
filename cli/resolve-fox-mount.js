// -----------------------------------------------------------------------------
// where the Fox runtime tree is mounted inside a game project
// -----------------------------------------------------------------------------
// Fox is now consumed as a standard Godot addon, mounted at `addons/fox`.
// Games mounted the runtime at `fox/` before that, and they are migrated one by
// one: both mounts are probed here, the addon first, so a single CLI serves a
// migrated project and a legacy one. The legacy candidate is a transition
// tolerance and goes away once every game has moved.
// -----------------------------------------------------------------------------

import fs from 'node:fs';
import path from 'node:path';

// -----------------------------------------------------------------------------

const ADDON_MOUNT = 'addons/fox';
const LEGACY_MOUNT = 'fox';

const FOX_MOUNTS = [ADDON_MOUNT, LEGACY_MOUNT];

// -----------------------------------------------------------------------------

// The mount holding `relativePath`, addon first. Nothing found means nothing is
// installed: the addon mount is returned anyway, so callers report the path
// they expect rather than the legacy one.
const resolveFoxMount = (relativePath, projectRoot = process.cwd()) =>
  FOX_MOUNTS.find((mount) => fs.existsSync(path.resolve(projectRoot, mount, relativePath))) ?? ADDON_MOUNT;

// -----------------------------------------------------------------------------

// Project relative path, as the CLI reads it from disk.
const resolveFoxPath = (relativePath, projectRoot = process.cwd()) =>
  path.join(resolveFoxMount(relativePath, projectRoot), relativePath);

// -----------------------------------------------------------------------------

// Godot resource path, as the engine reads it.
const resolveFoxResPath = (relativePath, projectRoot = process.cwd()) =>
  `res://${resolveFoxMount(relativePath, projectRoot)}/${relativePath}`;

// -----------------------------------------------------------------------------
// how the addon is mounted, for the commands that change the mount itself
// -----------------------------------------------------------------------------

const LINKED = 'linked';
const PINNED = 'pinned';
const MISSING = 'missing';

// `lstat` and not `stat`: a symlink to the fox checkout resolves to a real
// directory, so following it would report every dev mount as a pinned copy.
const describeMount = (projectRoot = process.cwd()) => {
  const mountPath = path.resolve(projectRoot, ADDON_MOUNT);

  let stats;

  try {
    stats = fs.lstatSync(mountPath);
  } catch {
    return { kind: MISSING, mountPath };
  }

  if (stats.isSymbolicLink()) {
    return { kind: LINKED, mountPath, target: fs.readlinkSync(mountPath) };
  }

  return { kind: PINNED, mountPath };
};

// -----------------------------------------------------------------------------

// The version the mounted addon declares. A linked mount reports whatever the
// fox checkout currently holds, which is NOT a released version: callers say so
// rather than presenting it as one.
const readMountedVersion = (projectRoot = process.cwd()) => {
  const configPath = path.resolve(projectRoot, ADDON_MOUNT, 'plugin.cfg');

  try {
    const match = fs.readFileSync(configPath, 'utf8').match(/^version="(.*)"$/m);
    return match ? match[1] : null;
  } catch {
    return null;
  }
};

// -----------------------------------------------------------------------------

// The line every command opens on: which mount this project uses, and which
// version it holds. That version is the one the GAME runs, and it is the only
// one worth reading here; the CLI's own is a `fox --version` away.
//
// Only a linked mount is spelled out, and with the word the game prints at boot.
// A pinned copy is the normal case and needs no adjective, while a linked one
// follows a checkout rather than a release: the version beside it is whatever
// that tree happens to hold.
const describeMountLabel = (projectRoot = process.cwd()) => {
  const { kind } = describeMount(projectRoot);

  if (kind === MISSING) {
    // A game still on the flat `fox/` mount predates `plugin.cfg`: there is no
    // version to read, and saying so is the useful part.
    const legacy = path.resolve(projectRoot, LEGACY_MOUNT, 'default.config.json');
    return fs.existsSync(legacy) ? `${LEGACY_MOUNT} (legacy mount)` : null;
  }

  const version = readMountedVersion(projectRoot) ?? 'unknown';
  const attachment = kind === LINKED ? ' (symlinked)' : '';

  return `${ADDON_MOUNT} ${version}${attachment}`;
};

// -----------------------------------------------------------------------------

export {
  ADDON_MOUNT,
  describeMount,
  describeMountLabel,
  LEGACY_MOUNT,
  LINKED,
  MISSING,
  PINNED,
  readMountedVersion,
  resolveFoxMount,
  resolveFoxPath,
  resolveFoxResPath,
};
