// -----------------------------------------------------------------------------
// resize screenshots to 1920x1080 for Steam store
// requires ImageMagick, see docs/install.md
// -----------------------------------------------------------------------------

import fs from 'node:fs';
import path from 'node:path';
import shell from 'shelljs';
import { ensureImageMagick, quote, runMagick } from './imagemagick.js';
import { screenshotsLogger } from './logger.js';

// -----------------------------------------------------------------------------

const RESOLUTION = '1920x1080';
const EXTENSIONS = ['.png', '.jpg', '.jpeg', '.webp'];

// -----------------------------------------------------------------------------

const generateSteamScreenshots = (config, params) => {
  const projectPath = path.resolve(process.cwd(), './');
  const input = params[0];

  if (!ensureImageMagick(screenshotsLogger)) {
    return false;
  }

  if (!input) {
    screenshotsLogger.error('Missing source folder argument');
    screenshotsLogger.log('Usage: fox generate:steam-screenshots <source-folder>');
    return false;
  }

  const inputPath = path.resolve(projectPath, input);

  if (!fs.existsSync(inputPath)) {
    screenshotsLogger.error(`Source folder not found: ${inputPath}`);
    return false;
  }

  const output = config.output;
  const outputPath = path.resolve(projectPath, output);

  screenshotsLogger.log('Generating Steam screenshots');
  screenshotsLogger.data({ input: inputPath, output: outputPath, resolution: RESOLUTION });

  if (!fs.existsSync(outputPath)) {
    shell.mkdir('-p', outputPath);
    screenshotsLogger.successCompact(`Created ${outputPath}`);
  }

  screenshotsLogger.step(1, 'Resizing screenshots');

  const files = fs.readdirSync(inputPath);
  let count = 0;

  for (const fileName of files) {
    const extension = path.extname(fileName);
    if (!EXTENSIONS.includes(extension.toLowerCase())) {
      continue;
    }

    const baseName = fileName.slice(0, -extension.length);
    const outputFileName = `${baseName}-${RESOLUTION}.png`;
    const outputFilePath = path.join(outputPath, outputFileName);

    const resized = runMagick(
      [
        quote(path.join(inputPath, fileName)),
        '-resize',
        quote(`${RESOLUTION}^`),
        '-gravity',
        'center',
        '-extent',
        quote(RESOLUTION),
        quote(outputFilePath),
      ],
      screenshotsLogger,
    );

    if (!resized) {
      screenshotsLogger.error(`Aborting: could not resize ${fileName} to ${RESOLUTION}`);
      return false;
    }

    screenshotsLogger.successCompact(`${fileName} → ${outputFileName}`);
    count++;
  }

  screenshotsLogger.done(`${count} Steam screenshot${count > 1 ? 's' : ''} generated`);
  return true;
};

// -----------------------------------------------------------------------------

export default generateSteamScreenshots;
