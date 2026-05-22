// -----------------------------------------------------------------------------
// resize screenshots to 1920x1080 for Steam store
// requires https://www.imagemagick.org/script/index.php
// OSX: brew install imagemagick
// -----------------------------------------------------------------------------

import fs from 'fs';
import path from 'path';
import shell from 'shelljs';
import {screenshotsLogger} from './logger.js';

// -----------------------------------------------------------------------------

const RESOLUTION = '1920x1080';
const EXTENSIONS = ['.png', '.jpg', '.jpeg', '.webp'];

// -----------------------------------------------------------------------------

const generateSteamScreenshots = (config, params) => {
  const projectPath = path.resolve(process.cwd(), './');
  const input = params[0];

  if (!input) {
    screenshotsLogger.error('Missing source folder argument');
    screenshotsLogger.log('Usage: fox generate:steam-screenshots <source-folder>');
    return;
  }

  const inputPath = path.resolve(projectPath, input);

  if (!fs.existsSync(inputPath)) {
    screenshotsLogger.error(`Source folder not found: ${inputPath}`);
    return;
  }

  const output = config.output;
  const outputPath = path.resolve(projectPath, output);

  screenshotsLogger.log('Generating Steam screenshots');
  screenshotsLogger.data({input: inputPath, output: outputPath, resolution: RESOLUTION});

  if (!fs.existsSync(outputPath)) {
    shell.mkdir('-p', outputPath);
    screenshotsLogger.successCompact(`Created ${outputPath}`);
  }

  screenshotsLogger.step(1, 'Resizing screenshots');

  const files = fs.readdirSync(inputPath);
  let count = 0;

  files.forEach((fileName) => {
    const extension = path.extname(fileName);
    if (!EXTENSIONS.includes(extension.toLowerCase())) {
      return;
    }

    const baseName = fileName.slice(0, -extension.length);
    const outputFileName = `${baseName}-${RESOLUTION}.png`;
    const outputFilePath = path.join(outputPath, outputFileName);

    shell.exec(
      `convert "${path.join(inputPath, fileName)}" -resize ${RESOLUTION}^ -gravity center -extent ${RESOLUTION} "${outputFilePath}"`,
      {silent: true}
    );

    screenshotsLogger.successCompact(`${fileName} → ${outputFileName}`);
    count++;
  });

  screenshotsLogger.done(`${count} Steam screenshot${count > 1 ? 's' : ''} generated`);
};

// -----------------------------------------------------------------------------

export default generateSteamScreenshots;
