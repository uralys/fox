// -----------------------------------------------------------------------------
// the CLI and the mount must come through the SAME channel
// -----------------------------------------------------------------------------
// Fox is installed two ways, and each one produces a coherent pair:
//
//   fox upgrade  ->  CLI under node_modules at tag T, mount = pinned copy of T
//   fox link     ->  CLI in a checkout,               mount = symlink onto it
//
// Anything else is off-channel, and one combination used to slip through in
// silence: a bare `npm link` in the fox checkout takes the global executable
// without touching the project, leaving a working tree CLI facing a pinned
// copy. The only pairing guard fox had compared VERSION STRINGS, and a checkout
// carries the version of its last release until `fox tag` moves it -- so the
// numbers agreed, nothing was printed, and unreleased commands ran against a
// frozen runtime as if they belonged to it.
//
// The version is therefore no longer the question. WHERE each half comes from
// is, and both facts are already on hand: `isLinkedCli()` for the executable,
// `describeMount()` for the runtime. Crossing them is what closes the hole.
// -----------------------------------------------------------------------------

import fs from 'node:fs';
import path from 'node:path';

import { isLinkedCli } from './install-cli.js';
import { foxLogger } from './logger.js';
import { ADDON_MOUNT, describeMount, LINKED, MISSING, readMountedVersion } from './resolve-fox-mount.js';

// -----------------------------------------------------------------------------

// `<checkout>/cli/cli.js` -> `<checkout>`, through the symlink npm wrote: the
// executable in the global bin is never the file itself.
const cliCheckout = () => {
  try {
    return path.dirname(path.dirname(fs.realpathSync(process.argv[1])));
  } catch {
    return null;
  }
};

// `<checkout>/addons/fox` -> `<checkout>`, for a mount that is a symlink.
const mountCheckout = (mountPath) => {
  try {
    return path.dirname(path.dirname(fs.realpathSync(mountPath)));
  } catch {
    return null;
  }
};

// -----------------------------------------------------------------------------

const refuse = ([headline, ...details]) => {
  foxLogger.error(headline);

  for (const line of details) {
    foxLogger.log(line);
  }

  return false;
};

// -----------------------------------------------------------------------------

// Returns false when the two halves disagree, and the caller stops there. The
// commands that REPAIR the pairing are exempt, otherwise a mismatched install
// would have no way out of itself.
const verifyChannel = (projectRoot = process.cwd()) => {
  const { kind, mountPath } = describeMount(projectRoot);

  // No mount at all is not a mismatch: it is a project that has never run
  // `fox upgrade`, and the missing default config says so a few lines later.
  if (kind === MISSING) {
    return true;
  }

  const linkedCli = isLinkedCli();
  const linkedMount = kind === LINKED;

  if (linkedCli && !linkedMount) {
    return refuse([
      `your \`fox\` runs from a checkout while ${ADDON_MOUNT} is a pinned ${readMountedVersion(projectRoot) ?? 'unknown'} copy`,
      'The CLI and the runtime would come from two different trees.',
      'Follow your checkout in this project: fox link ../fox',
      'Or go back to a release: fox upgrade',
    ]);
  }

  if (!linkedCli && linkedMount) {
    return refuse([
      `${ADDON_MOUNT} follows a checkout while your \`fox\` is a released version`,
      'The CLI and the runtime would come from two different trees.',
      'Link the executable too: fox link ../fox',
      'Or go back to a release: fox upgrade',
    ]);
  }

  if (linkedCli && linkedMount) {
    const cli = cliCheckout();
    const mount = mountCheckout(mountPath);

    if (cli && mount && cli !== mount) {
      return refuse([
        'your `fox` and your mount follow two different checkouts',
        `CLI: ${cli}`,
        `${ADDON_MOUNT}: ${mount}`,
        `Relink both on one of them: fox link ${path.relative(projectRoot, cli)}`,
      ]);
    }
  }

  return true;
};

// -----------------------------------------------------------------------------

export { verifyChannel };
