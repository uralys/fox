// -----------------------------------------------------------------------------
// fox link: mount the local fox checkout, so the game follows it live
// -----------------------------------------------------------------------------
// The counterpart of `fox upgrade`. A linked game rides the working tree of the
// fox repository: handy while developing Fox itself, and deliberately unsuited
// to shipping, since the version `plugin.cfg` declares is then whatever the
// checkout happens to hold rather than a released one.
// -----------------------------------------------------------------------------

import fs from 'node:fs';
import path from 'node:path';

import { ignoreMount } from './ignore-mount.js';
import { reimportProject } from './import-assets.js';
import { linkCli } from './install-cli.js';
import { linkLogger } from './logger.js';
import { ADDON_MOUNT, describeMount, LINKED, MISSING, readMountedVersion } from './resolve-fox-mount.js';

// -----------------------------------------------------------------------------

// Fox is cloned next to the games, the layout every project of the folder uses.
const DEFAULT_CHECKOUT = '../fox';

// -----------------------------------------------------------------------------

const link = async (params = []) => {
  const projectRoot = process.cwd();
  // Flags are skipped rather than read as the checkout path: `fox link
  // --no-import` used to look for a fox addon inside a folder named after the
  // flag.
  const requested = params.find((param) => !param.startsWith('-')) ?? DEFAULT_CHECKOUT;
  const checkout = path.resolve(projectRoot, requested);
  const source = path.join(checkout, ADDON_MOUNT);

  linkLogger.log(`Linking ${ADDON_MOUNT} to ${source}`);

  if (!fs.existsSync(path.join(source, 'plugin.cfg'))) {
    linkLogger.error(`No fox addon in ${source}`);
    linkLogger.log('Pass the path to your fox checkout: fox link ../../fox');
    return false;
  }

  const { kind, mountPath } = describeMount(projectRoot);

  if (kind === LINKED) {
    linkLogger.warn('Already linked, relinking');
    fs.unlinkSync(mountPath);
  } else if (kind !== MISSING) {
    const version = readMountedVersion(projectRoot);
    linkLogger.warn(`Replacing the pinned ${version ?? 'unknown'} copy`);
    fs.rmSync(mountPath, { recursive: true, force: true });
  }

  fs.mkdirSync(path.dirname(mountPath), { recursive: true });

  // A relative checkout is stored relative, so the committed link keeps working
  // on another machine where the projects live elsewhere; an absolute one is
  // stored as given, rather than turned into a stack of `..` reaching the root.
  const target = path.isAbsolute(requested) ? source : path.relative(path.dirname(mountPath), source);

  fs.symlinkSync(target, mountPath);

  linkLogger.success(`${ADDON_MOUNT} -> ${fs.readlinkSync(mountPath)}`);
  linkLogger.warn('Linked: the game now follows your checkout, not a released version');

  // `core.fox` is deliberately left as it was: it records the RELEASE a game
  // ships against, and a checkout is not one. The ignore, on the other hand, is
  // never more useful than here: a tracked mount turns this symlink into every
  // file under it reported as deleted.
  if (!params.includes('--no-gitignore')) {
    ignoreMount(projectRoot, linkLogger);
  }

  // Same checkout for the executable: linking the runtime and leaving the CLI
  // pinned would have the two halves of Fox come from two different trees.
  if (!params.includes('--no-cli')) {
    linkCli(checkout, linkLogger);
  }

  if (params.includes('--no-import')) {
    linkLogger.done('run `fox import` to reimport the addon');
    return true;
  }

  return await reimportProject(projectRoot, linkLogger);
};

// -----------------------------------------------------------------------------

export default link;
