// -----------------------------------------------------------------------------

import fs from 'fs';
import inquirer from 'inquirer';
import shell from 'shelljs';

// -----------------------------------------------------------------------------

import {versionLogger} from '../logger.js';
import {getNextVersion, toVersionNumber} from './versioning.js';
import {readPresets, writePresets, PRESETS_CFG} from './read-presets.js';
import {updateVersionInPreset} from './update-preset.js';

// -----------------------------------------------------------------------------

const PROJECT_GODOT = 'project.godot';
const SEMVER_LEVELS = ['patch', 'minor', 'major'];

// -----------------------------------------------------------------------------

const readProjectVersion = () => {
  const content = fs.readFileSync(PROJECT_GODOT, 'utf8');
  const match = content.match(/^version="(.+)"$/m);

  if (!match) {
    versionLogger.error('No version found in project.godot [bundle] section');
    return null;
  }

  return match[1];
};

// -----------------------------------------------------------------------------

const writeProjectVersion = (newVersion) => {
  let content = fs.readFileSync(PROJECT_GODOT, 'utf8');
  const versionCode = toVersionNumber(newVersion);

  content = content.replace(/^version=".*"$/m, `version="${newVersion}"`);
  content = content.replace(/^versionCode=.*$/m, `versionCode=${versionCode}`);

  fs.writeFileSync(PROJECT_GODOT, content);
  versionLogger.success(`project.godot updated to ${newVersion} (code: ${versionCode})`);
};

// -----------------------------------------------------------------------------

const inquireVersionLevel = async (currentVersion) => {
  const {versionLevel} = await inquirer.prompt([
    {
      message: 'version',
      name: 'versionLevel',
      type: 'list',
      choices: [`${currentVersion}`, ...SEMVER_LEVELS]
    }
  ]);

  return versionLevel;
};

// -----------------------------------------------------------------------------

const tagVersion = async (levelArg) => {
  const currentVersion = readProjectVersion();

  if (!currentVersion) {
    return null;
  }

  versionLogger.log(`Current version: ${currentVersion}`);

  const versionLevel = levelArg || await inquireVersionLevel(currentVersion);
  const keepCurrent = versionLevel === currentVersion;

  if (keepCurrent) {
    versionLogger.log(`Keeping version ${currentVersion}`);
    return currentVersion;
  }

  const newVersion = getNextVersion(currentVersion, versionLevel);
  writeProjectVersion(newVersion);

  const filesToCommit = [PROJECT_GODOT];

  if (fs.existsSync(PRESETS_CFG)) {
    const presets = readPresets();
    if (presets) {
      Object.keys(presets).forEach(num => {
        updateVersionInPreset(presets[num], newVersion);
      });
      writePresets(presets);
      filesToCommit.push(PRESETS_CFG);
    }
  }

  versionLogger.step(0, 'git commit');
  shell.exec(`git add ${filesToCommit.join(' ')}`);
  shell.exec(`git commit -m 'v${newVersion}'`);

  versionLogger.step(1, 'git tag');
  shell.exec(`git tag v${newVersion}`);

  versionLogger.done(`Tagged v${newVersion}`);
  return newVersion;
};

// -----------------------------------------------------------------------------

export {readProjectVersion, writeProjectVersion, tagVersion, SEMVER_LEVELS};
