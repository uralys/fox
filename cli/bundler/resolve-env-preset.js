// -----------------------------------------------------------------------------

import fs from 'fs';

// -----------------------------------------------------------------------------

import ini from './ini.js';

// -----------------------------------------------------------------------------

const OVERRIDE_CFG = './override.cfg';

// -----------------------------------------------------------------------------

export const readCurrentBundle = () => {
  try {
    const override = ini.parse(fs.readFileSync(OVERRIDE_CFG, 'utf8'));
    return override.bundle || null;
  } catch (e) {
    return null;
  }
};

export const readCurrentEnv = () => {
  const bundle = readCurrentBundle();
  return bundle ? bundle.env || null : null;
};

// -----------------------------------------------------------------------------

export const findPreset = (presets, platform, env) => {
  const match = Object.keys(presets).find((num) => {
    const preset = presets[num];
    const features = (preset.custom_features || '').split(',').map((feature) => feature.trim());
    return preset.platform === platform && features.includes(`env:${env}`);
  });

  return match ? presets[match] : null;
};
