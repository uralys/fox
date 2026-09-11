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

export { ADDON_MOUNT, LEGACY_MOUNT, resolveFoxMount, resolveFoxPath, resolveFoxResPath };
