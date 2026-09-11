// -----------------------------------------------------------------------------
// keep the `fox` executable on the same Fox as the mounted addon
// -----------------------------------------------------------------------------
// Fox ships through two channels, and only one of them used to be pinned. The
// runtime under `addons/fox` is copied into the game and frozen; the CLI was a
// symlink on a checkout, so every edit to `cli/` reached every game at once. A
// game could therefore be pinned against a runtime regression while remaining
// fully exposed to a CLI one.
//
// `fox upgrade` now installs the CLI of the version it pins, and `fox link`
// links the checkout, so the executable follows the mount it just wrote.
//
// ⚠️ The executable is global, one per machine, while a mount is per project:
// the last command run owns it. Two projects on different versions cannot each
// keep their own `fox`, and the header says so when the running CLI and the
// mounted addon disagree.
// -----------------------------------------------------------------------------

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

// -----------------------------------------------------------------------------

const REPOSITORY = 'uralys/fox';
const EXECUTABLE = 'fox';

// -----------------------------------------------------------------------------

const npm = (args, cwd) => {
  execFileSync('npm', args, { cwd, stdio: 'inherit' });
};

// -----------------------------------------------------------------------------

const globalBin = () => {
  try {
    return path.join(execFileSync('npm', ['prefix', '-g'], { encoding: 'utf8' }).trim(), 'bin');
  } catch {
    return null;
  }
};

const installedExecutable = () => {
  const bin = globalBin();
  return bin ? fs.existsSync(path.join(bin, EXECUTABLE)) : false;
};

// -----------------------------------------------------------------------------

// A `fox` sitting earlier in the PATH than the one npm just wrote would shadow
// it, and the upgrade would look like it did nothing. The hand written symlink
// documented before the CLI was packaged is exactly that case.
const warnAboutShadowing = (logger) => {
  const npmBin = globalBin();

  if (!npmBin) {
    return;
  }

  const entries = (process.env.PATH ?? '').split(path.delimiter).filter(Boolean);

  for (const entry of entries) {
    const candidate = path.join(entry, EXECUTABLE);

    if (!fs.existsSync(candidate)) {
      continue;
    }

    if (path.resolve(entry) !== path.resolve(npmBin)) {
      logger.warn(`${candidate} comes first in your PATH and shadows the one npm installed`);
      logger.log(`Remove it to use the pinned CLI: rm ${candidate}`);
    }

    return;
  }
};

// -----------------------------------------------------------------------------

// Installed from the git tag rather than the npm registry: the package is not
// published, and the tag is the same source of truth the addon is taken from,
// so the executable and the runtime can never come from two different trees.
const pinCli = (tag, logger) => {
  logger.log(`Installing the ${tag} CLI`);

  try {
    npm(['install', '-g', `github:${REPOSITORY}#${tag}`]);
  } catch {
    logger.warn(`Could not install the ${tag} CLI: your \`fox\` executable is unchanged`);
    return true;
  }

  // npm reports success for a package it installed without an executable, and
  // every tag up to 2.0.2 is such a package: `bin` was only declared when the
  // CLI became pinnable. Claiming the executable moved would be a lie the user
  // only discovers when an old command misbehaves, so the outcome is checked
  // rather than assumed.
  if (!installedExecutable()) {
    logger.warn(`The ${tag} package declares no executable: your \`fox\` is unchanged`);
    logger.log('Versions up to 2.0.2 cannot be pinned this way, only the addon was.');
    return true;
  }

  logger.success(`\`${EXECUTABLE}\` is now ${tag}`);
  warnAboutShadowing(logger);

  return true;
};

// -----------------------------------------------------------------------------

const linkCli = (checkout, logger) => {
  logger.log(`Linking the CLI on ${checkout}`);

  try {
    npm(['link'], checkout);
  } catch {
    logger.warn('Could not link the CLI: your `fox` executable is unchanged');
    return true;
  }

  logger.success(`\`${EXECUTABLE}\` now runs from your checkout`);
  warnAboutShadowing(logger);

  return true;
};

// -----------------------------------------------------------------------------
// Whether the running `fox` is a checkout rather than a published version.
//
// The question is not whether symlinks are involved: the executable npm writes
// is ALWAYS a symlink, and comparing its target to its realpath only catches
// `npm link`. A hand written symlink pointing straight at `cli/cli.js` in a
// checkout has a target and a realpath that agree, and used to be reported as a
// pinned release while running the working tree.
//
// What actually separates the two is WHERE the running file lives. A version
// installed from a tag always sits under `node_modules`; a checkout never does,
// however it was reached: `npm link`, a hand written symlink, or plain
// `node cli/cli.js`.

const isLinkedCli = () => {
  const invoked = process.argv[1];

  if (!invoked) {
    return false;
  }

  try {
    return !fs.realpathSync(invoked).split(path.sep).includes('node_modules');
  } catch {
    return false;
  }
};

// -----------------------------------------------------------------------------

export { isLinkedCli, linkCli, pinCli };
