// -----------------------------------------------------------------------------

import fs from 'fs';

// -----------------------------------------------------------------------------

import ini from './ini.js';

// -----------------------------------------------------------------------------

const OVERRIDE_CFG = './override.cfg';

// A build is identified by TWO orthogonal axes, and a preset declares both in its
// `custom_features`:
//
//   env:<debug|demo|release>   what the build CONTAINS (feature scope)
//   target:<steam|itch|...>    where it is PUBLISHED (store plumbing)
//
// They cross freely: the same `demo` content ships to Steam with an app id and a
// Workshop, and to itch.io with neither. Anything that is a store concern belongs
// to the target, anything that is a content concern belongs to the env — a value
// that means "the demo on Steam" belongs to neither and is a bug.
export const DEFAULT_TARGET = 'steam';

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

export const readCurrentTarget = () => {
  const bundle = readCurrentBundle();
  return (bundle && bundle.target) || null;
};

// -----------------------------------------------------------------------------

const featuresOf = (preset) =>
  (preset.custom_features || '').split(',').map((feature) => feature.trim());

export const presetTarget = (preset) => {
  const declared = featuresOf(preset).find((feature) => feature.startsWith('target:'));
  return declared ? declared.slice('target:'.length) : null;
};

export const presetEnv = (preset) => {
  const declared = featuresOf(preset).find((feature) => feature.startsWith('env:'));
  return declared ? declared.slice('env:'.length) : null;
};

// A project that predates the target axis declares `env:` alone. Such a preset
// keeps matching every target, so `fox` stays usable on games that never had a
// second store — declaring one target anywhere does not force the others to.
export const findPreset = (presets, platform, env, target = DEFAULT_TARGET) => {
  const candidates = Object.keys(presets)
    .map((num) => presets[num])
    .filter((preset) => preset.platform === platform && presetEnv(preset) === env);

  return (
    candidates.find((preset) => presetTarget(preset) === target) ||
    candidates.find((preset) => presetTarget(preset) === null) ||
    null
  );
};

// Every target a project declares a preset for, in declaration order.
export const declaredTargets = (presets) => {
  const targets = Object.keys(presets)
    .map((num) => presetTarget(presets[num]))
    .filter(Boolean);

  return [...new Set(targets)];
};

// Every target that can actually be built for this env on some platform.
export const targetsForEnv = (presets, env) => {
  const targets = Object.keys(presets)
    .map((num) => presets[num])
    .filter((preset) => presetEnv(preset) === env)
    .map((preset) => presetTarget(preset) || DEFAULT_TARGET);

  return [...new Set(targets)];
};
