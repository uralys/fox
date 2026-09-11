// -----------------------------------------------------------------------------
// core.fox: the version of the runtime a game declares
// -----------------------------------------------------------------------------
// `addons/fox` is a dependency, not game code: it is mounted by `fox upgrade`,
// replaced whole on every upgrade, and swapped for a symlink by `fox link`. A
// game that commits it therefore carries hundreds of files it never edits, and
// sees them all deleted the moment a contributor links a checkout.
//
// Ignoring the mount costs a game the only record of the version it runs, since
// that version lives in `addons/fox/plugin.cfg`, INSIDE what is being ignored.
// `core.fox` is that record, kept in the config the game already commits: the
// `package.json` half of a `node_modules` that is finally ignorable.
//
// The pin is written as a surgical edit rather than a reparse: `fox.config.json`
// is hand maintained, and rewriting it through `JSON.stringify` would reorder
// its keys and drop its formatting on a file nobody asked to touch.
// -----------------------------------------------------------------------------

import fs from 'node:fs';
import path from 'node:path';

// -----------------------------------------------------------------------------

const CONFIG_FILE = 'fox.config.json';

const configPath = (projectRoot) => path.resolve(projectRoot, CONFIG_FILE);

// -----------------------------------------------------------------------------

const readConfigFile = (projectRoot) => {
  try {
    return fs.readFileSync(configPath(projectRoot), 'utf8');
  } catch {
    return null;
  }
};

// -----------------------------------------------------------------------------

// The version the game declares, or null when it declares none: a project
// predating the pin is a normal project, not a broken one.
const readPinnedVersion = (projectRoot = process.cwd()) => {
  const source = readConfigFile(projectRoot);

  if (!source) {
    return null;
  }

  try {
    return JSON.parse(source).core?.fox ?? null;
  } catch {
    return null;
  }
};

// -----------------------------------------------------------------------------

// `"fox": "2.3.0"` inside the `core` block, replaced when it is there and
// inserted right under `"core": {` when it is not. The indentation is taken
// from the line that follows the block opening, so the pin lands aligned with
// whatever the file already uses.
const CORE_OPENING = /^(\s*)"core"\s*:\s*\{[^\n]*\n/m;
const EXISTING_PIN = /^(\s*)"fox"\s*:\s*"[^"]*"(,?)([^\n]*)$/m;

const writePinnedVersion = (version, projectRoot = process.cwd(), logger) => {
  const source = readConfigFile(projectRoot);

  if (source === null) {
    logger?.warn(`No ${CONFIG_FILE}: add "fox": "${version}" to its "core" block once you have one`);
    return false;
  }

  if (readPinnedVersion(projectRoot) === version) {
    return true;
  }

  let updated;

  if (EXISTING_PIN.test(source)) {
    updated = source.replace(EXISTING_PIN, `$1"fox": "${version}"$2$3`);
  } else {
    const opening = source.match(CORE_OPENING);

    if (!opening) {
      logger?.warn(`Could not find a "core" block in ${CONFIG_FILE}: add "fox": "${version}" to it`);
      return false;
    }

    // One level deeper than `"core"` itself, in the file's own indentation: two
    // spaces unless the block sits somewhere unusual, in which case its own
    // indent is doubled rather than a convention imposed on the file.
    const indent = opening[1] ? opening[1].repeat(2) : '  ';
    updated = source.replace(CORE_OPENING, `${opening[0]}${indent}"fox": "${version}",\n`);
  }

  // The result has to survive being read back: a pin written into a file it
  // corrupted would be worse than no pin at all.
  try {
    JSON.parse(updated);
  } catch {
    logger?.warn(`Could not pin ${version} in ${CONFIG_FILE}: add "fox": "${version}" to its "core" block`);
    return false;
  }

  fs.writeFileSync(configPath(projectRoot), updated);
  logger?.log(`Pinned ${version} in ${CONFIG_FILE}`);

  return true;
};

// -----------------------------------------------------------------------------

export { CONFIG_FILE, readPinnedVersion, writePinnedVersion };
