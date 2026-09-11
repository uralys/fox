// -----------------------------------------------------------------------------

import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import shell from 'shelljs';

import { foxLogger, godotLogger } from './logger.js';
import resolveGodotPath from './resolve-godot.js';

// -----------------------------------------------------------------------------

const IMPORTED_CACHE = '.godot/imported';
const FORCE_FLAGS = ['--force', '-f'];

// -----------------------------------------------------------------------------

// `--import` boots the editor headless: it runs the same EditorFileSystem scan
// as opening the editor (autoloads, editor plugins, EditorScenePostImport
// scripts), reimports what is outdated, then quits. It is incremental: only a
// wiped `.godot/imported` cache forces everything to be reimported.
const importAssets = (godotPath, params) =>
  new Promise((resolve) => {
    const force = params.some((param) => FORCE_FLAGS.includes(param));
    const extraParams = params.filter((param) => !FORCE_FLAGS.includes(param));

    godotLogger.log('Importing assets');
    godotLogger.data({
      mode: force ? 'force (full reimport)' : 'incremental (outdated files only)',
      project: process.cwd(),
    });

    if (force) {
      const cache = path.resolve(process.cwd(), IMPORTED_CACHE);

      if (fs.existsSync(cache)) {
        shell.rm('-rf', cache);
        godotLogger.success(`Cleared ${IMPORTED_CACHE}`);
      }
    }

    const importProcess = spawn(godotPath, ['--headless', '--path', '.', '--import', ...extraParams], {
      stdio: 'inherit',
    });

    importProcess.on('close', (code) => {
      if (code !== 0) {
        foxLogger.error(`Godot exited with code ${code}`);
        resolve(false);
        return;
      }

      godotLogger.success('Assets are up to date');
      resolve(true);
    });
  });

// -----------------------------------------------------------------------------

// Reimport after the addon mount changed, for `fox upgrade` and `fox link`.
//
// A freshly mounted addon carries no `.import` sidecar: they are generated per
// project and never travel with a release. Godot therefore sees an addon it
// cannot load until the project is reimported, which made every mount change a
// two command ritual for no reason.
//
// Reading `core.godot` from `fox.config.json` here is best effort: both
// commands deliberately run BEFORE the config is loaded, since they install the
// very folder holding the default config. A project with no config, or a
// machine with no Godot, still completes: the reimport is skipped and said out
// loud rather than failing the command.
const reimportProject = async (projectRoot, logger) => {
  let configuredGodot;

  try {
    const config = JSON.parse(fs.readFileSync(path.resolve(projectRoot, 'fox.config.json'), 'utf8'));
    configuredGodot = config.core?.godot;
  } catch {
    configuredGodot = undefined;
  }

  const godotPath = resolveGodotPath(configuredGodot);

  if (!godotPath) {
    logger.warn('Skipping the reimport: run `fox import` once Godot is available');
    return true;
  }

  return await importAssets(godotPath, []);
};

// -----------------------------------------------------------------------------

export default importAssets;
export { reimportProject };
