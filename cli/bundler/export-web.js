// -----------------------------------------------------------------------------
// Non-interactive HTML5/Web export — the SCRIPTABLE path, not the publishable one.
//
// It finds the `platform="Web"` preset in export_presets.cfg and runs a headless
// `--export-debug`, nothing else. Meant for an automated pipeline (e.g. Coucarel's
// generated games) that just needs a playable web build out of a repo it also
// generated, with no env to choose and no store behind it.
//
// It writes into `_build/web/`, never into the preset's own `export_path`: that
// folder is what `fox publish` uploads, and this command has no business filling
// it.
//
// ⛔ What comes out is NOT shippable: the build carries whatever `[bundle]` the
// working tree happens to hold (`env`, `target`), so it can claim to be a debug
// Steam build while sitting in an itch folder. A build meant for players goes
// through `fox export`, which knows the Web platform: it asks for the
// env and the target, bakes them into project.godot, exports with
// `--export-release` for a shipping env, and restores the repo afterwards.
// -----------------------------------------------------------------------------

import fs from 'fs';
import path from 'path';
import shell from 'shelljs';
import {spawn} from 'child_process';

// -----------------------------------------------------------------------------

import {foxLogger, godotLogger} from '../logger.js';
import {readPresets} from './read-presets.js';

// -----------------------------------------------------------------------------

const WEB_PLATFORM = 'Web';
const DEFAULT_EXPORT_PATH = '_build/web/index.html';

// -----------------------------------------------------------------------------

const findWebPreset = (presets) =>
  Object.values(presets).find((preset) => preset.platform === WEB_PLATFORM) ||
  null;

// -----------------------------------------------------------------------------

const exportWeb = (settings) => {
  const {core} = settings;

  const presets = readPresets();
  if (!presets) {
    return;
  }

  const preset = findWebPreset(presets);
  if (!preset) {
    foxLogger.error('No Web preset in export_presets.cfg (platform="Web")');
    foxLogger.error('Add one via Godot editor > Project > Export, or ship it in the starter');
    return;
  }

  // ⛔ The preset's own `export_path` is NOT used: it points at
  // `export/<env>/<target>/web/`, the very folder `fox publish` uploads. A
  // debug build with no bundle bake dropped there is shipped to players by the
  // next publish, with nothing on screen to say the bytes changed. Godot takes
  // the destination as the argument after the preset name, so this build lands
  // in `_build/`, which every project already excludes from its exports.
  const exportPath = DEFAULT_EXPORT_PATH;
  const exportDir = path.dirname(path.resolve(process.cwd(), exportPath));

  if (!fs.existsSync(exportDir)) {
    shell.mkdir('-p', exportDir);
    godotLogger.success(`Created ${exportDir}`);
  }

  foxLogger.step(0, `Exporting Web build "${preset.name}" -> ${exportPath}`);

  return new Promise((resolve) => {
    const bundler = spawn(
      core.godot,
      ['--headless', '--export-debug', preset.name, exportPath],
      {stdio: [process.stdin, process.stdout, process.stderr]}
    );

    bundler.on('close', (code) => {
      if (code !== 0) {
        godotLogger.error(`Web export failed for "${preset.name}" (exit ${code})`);
        resolve(false);
        return;
      }

      foxLogger.done(`Web build ready at ${exportDir}`);
      resolve(true);
    });
  });
};

// -----------------------------------------------------------------------------

export default exportWeb;
