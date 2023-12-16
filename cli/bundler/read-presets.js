// -----------------------------------------------------------------------------

import chalk from 'chalk';
import fs from 'fs';
import path from 'path';
import ini from './ini.js';

// -----------------------------------------------------------------------------

export const PRESETS_CFG = 'export_presets.cfg';

// -----------------------------------------------------------------------------

const readPresets = () => {
  let presets;

  try {
    const presetsCFG = fs.readFileSync(path.resolve(PRESETS_CFG), 'utf8');
    presets = ini.parse(presetsCFG).preset;
  } catch (e) {
    console.log(e);
    console.log(`\nCould not open ${path.resolve(PRESETS_CFG)}`);
    console.log(chalk.red.bold('🔴 failed: use Godot editor > Project > Export to define your export config.'));
    return;
  }

  return presets;
}

// -----------------------------------------------------------------------------

const writePresets = (presets) => {
  fs.writeFileSync(PRESETS_CFG, ini.stringify({preset: presets}));
}

// -----------------------------------------------------------------------------

export {readPresets, writePresets};
