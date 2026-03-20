// -----------------------------------------------------------------------------

import fs from 'fs';
import readline from 'readline';
import shell from 'shelljs';

// -----------------------------------------------------------------------------

import {createLogger} from '../logger.js';
import {getNextVersion, toVersionNumber} from './versioning.js';
import {readPresets, writePresets, PRESETS_CFG} from './read-presets.js';
import {updateVersionInPreset} from './update-preset.js';

// -----------------------------------------------------------------------------

const PROJECT_GODOT = 'project.godot';
const SEMVER_LEVELS = ['patch', 'minor', 'major'];

// -----------------------------------------------------------------------------

const readProjectGodot = () => {
  const content = fs.readFileSync(PROJECT_GODOT, 'utf8');

  const versionMatch = content.match(/^version="(.+)"$/m);
  const nameMatch = content.match(/^config\/name="(.+)"$/m);

  return {
    version: versionMatch ? versionMatch[1] : null,
    name: nameMatch ? nameMatch[1] : null
  };
};

// -----------------------------------------------------------------------------

const writeProjectVersion = (newVersion) => {
  let content = fs.readFileSync(PROJECT_GODOT, 'utf8');
  const versionCode = toVersionNumber(newVersion);

  content = content.replace(/^version=".*"$/m, `version="${newVersion}"`);
  content = content.replace(/^versionCode=.*$/m, `versionCode=${versionCode}`);

  fs.writeFileSync(PROJECT_GODOT, content);
};

// -----------------------------------------------------------------------------

const inquireVersionLevel = async (currentVersion) => {
  const versions = SEMVER_LEVELS.map(level => getNextVersion(currentVersion, level));

  console.log('Select next version:');
  versions.forEach((v, i) => console.log(`  ${i + 1}) ${v}`));

  const rl = readline.createInterface({input: process.stdin, output: process.stdout});

  const answer = await new Promise(resolve => {
    rl.question('Enter choice [1-3] (default: 1): ', resolve);
  });

  rl.close();

  const index = parseInt(answer || '1') - 1;
  return SEMVER_LEVELS[index] || SEMVER_LEVELS[0];
};

// -----------------------------------------------------------------------------

const tagVersion = async (levelArg) => {
  const {version: currentVersion, name: projectName} = readProjectGodot();
  const logger = createLogger({name: projectName || 'Tag', color: 'blue'});

  if (!currentVersion) {
    logger.error('No version found in project.godot [bundle] section');
    return null;
  }

  logger.log(`Current version: ${currentVersion}`);

  const versionLevel = levelArg || await inquireVersionLevel(currentVersion);
  const newVersion = getNextVersion(currentVersion, versionLevel);
  writeProjectVersion(newVersion);
  logger.success(`project.godot updated to ${newVersion} (code: ${toVersionNumber(newVersion)})`);

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

  logger.step(0, 'git commit');
  shell.exec(`git add ${filesToCommit.join(' ')}`);
  shell.exec(`git commit -m 'v${newVersion}'`);

  logger.step(1, 'git tag');
  shell.exec(`git tag v${newVersion}`);

  logger.done(`Tagged v${newVersion}`);
  return newVersion;
};

// -----------------------------------------------------------------------------

const readProjectVersion = () => readProjectGodot().version;

export {readProjectVersion, writeProjectVersion, tagVersion, SEMVER_LEVELS};
