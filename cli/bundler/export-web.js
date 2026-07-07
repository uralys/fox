// -----------------------------------------------------------------------------
// Non-interactive HTML5/Web export.
//
// Unlike `fox export` (interactive, desktop/Steam-oriented: inquires a platform,
// requires a prior `fox switch`, tags a version and patches project.godot's
// [bundle] + Steam app_id), this is a single scriptable step: it finds the
// `platform="Web"` preset in export_presets.cfg and runs a headless
// `--export-debug`, nothing else. Meant to be called from an automated pipeline
// (e.g. Coucarel's generated games) that just needs a playable web build.
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

  const exportPath = preset.export_path || DEFAULT_EXPORT_PATH;
  const exportDir = path.dirname(path.resolve(process.cwd(), exportPath));

  if (!fs.existsSync(exportDir)) {
    shell.mkdir('-p', exportDir);
    godotLogger.success(`Created ${exportDir}`);
  }

  foxLogger.step(0, `Exporting Web build "${preset.name}" -> ${exportPath}`);

  return new Promise((resolve) => {
    const bundler = spawn(
      core.godot,
      ['--headless', '--export-debug', preset.name],
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
