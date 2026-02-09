// -----------------------------------------------------------------------------

import fs from 'fs';
import path from 'path';

// -----------------------------------------------------------------------------

import {presetsLogger} from '../logger.js';
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
    presetsLogger.error(`Could not open ${path.resolve(PRESETS_CFG)}`);
    presetsLogger.error('Use Godot editor > Project > Export to define your export config');
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
