// -----------------------------------------------------------------------------

import path from 'path';
import shell from 'shelljs';

// -----------------------------------------------------------------------------

import {versionLogger} from '../logger.js';
import { updateVersionInPreset } from "./update-preset.js";
import { PRESETS_CFG, writePresets } from './read-presets.js';

// -----------------------------------------------------------------------------

const getNextVersion = (currentVersion, versionLevel) => {
  const [major, minor, patch] = currentVersion.split('.');

  switch(versionLevel) {
    case 'major':
      return `${parseInt(major) + 1}.0.0`;
    case 'minor':
      return `${major}.${parseInt(minor) + 1}.0`;
    case 'patch':
      return `${major}.${minor}.${parseInt(patch) + 1}`;
  }
}

// -----------------------------------------------------------------------------
// from https://github.com/chrisdugne/cherry/blob/master/cherry/libs/version-number.lua
// -----------------------------------------------------------------------------
/*
  console.log('1.2.3', toVersionNumber('1.2.3'));  --> 10203
  console.log('1.2.32', toVersionNumber('1.2.32'));  --> 10232
  console.log('12.2.32', toVersionNumber('12.2.32'));  --> 120232
  console.log('12.24.32', toVersionNumber('12.24.32'));  --> 122432
  console.log('1.2', toVersionNumber('1.2'));  --> 10200
  console.log('1', toVersionNumber('1'));  --> 10000
  console.log(12, toVersionNumber(12));  --> 0
  console.log('undefined', toVersionNumber());  --> 0
  console.log(null, toVersionNumber(null));  --> 0
  console.log('whatever.not.number', toVersionNumber('whatever.not.number'));  --> 0
*/
const toVersionNumber = (semver) => {
  if (!semver) return 0;
  if (typeof semver !== 'string') return 0;

  const splinters = semver.split('.');

  const code = splinters.reduce((acc, splinter) => acc + splinter.padStart(2, '0'), '');
  const number = parseInt(code.padEnd(6, 0)) || 0;

  return number;
};

// -----------------------------------------------------------------------------

const increasePackageVersion = (newVersion, versionLevel) => {
  versionLogger.log(`npm version ${versionLevel}`);

  try {
    versionLogger.step(0, 'git add presets');
    shell.exec(`git add ${path.resolve(PRESETS_CFG)}`);
    shell.exec(`git commit -m "bump presets version to ${newVersion}"`);
    shell.exec(`npm version ${versionLevel}`);
    versionLogger.success(`Version bumped to ${newVersion}`);
  } catch (e) {
    versionLogger.error(`Failed during versioning, check "git status"`);
    return;
  }
};

// -----------------------------------------------------------------------------

const increasePresetsVersion = (newVersion, presets) => {
  Object.keys(presets).forEach(num => {
    updateVersionInPreset(presets[num], newVersion);
  })

  writePresets(presets);
};

// -----------------------------------------------------------------------------

export {
  getNextVersion,
  toVersionNumber,
  increasePackageVersion,
  increasePresetsVersion
};
