// -----------------------------------------------------------------------------

import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import shell from 'shelljs';

import { foxLogger, godotLogger } from './logger.js';

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

export default importAssets;
