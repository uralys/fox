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

// A `fox` sitting earlier in the PATH than the one npm just wrote would shadow
// it, and the upgrade would look like it did nothing. The hand written symlink
// documented before the CLI was packaged is exactly that case.
const warnAboutShadowing = (logger) => {
  let npmBin;

  try {
    npmBin = path.join(execFileSync('npm', ['prefix', '-g'], { encoding: 'utf8' }).trim(), 'bin');
  } catch {
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

export { linkCli, pinCli };
