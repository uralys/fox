// -----------------------------------------------------------------------------
// resize screenshots to match store requirements
// requires ImageMagick, see docs/install.md
// -----------------------------------------------------------------------------

import fs from 'node:fs';
import path from 'node:path';
import shell from 'shelljs';
import { ensureImageMagick, quote, runMagick } from './imagemagick.js';
import { screenshotsLogger } from './logger.js';

// -----------------------------------------------------------------------------

const generateScreenshots = (config) => {
  const { orientation, input, output, sizes } = config;
  const projectPath = path.resolve(process.cwd(), './');

  if (!ensureImageMagick(screenshotsLogger)) {
    return false;
  }

  screenshotsLogger.log('Generating screenshots');
  screenshotsLogger.data({ orientation, input, output });

  screenshotsLogger.step(0, 'Verifying folders');

  sizes.forEach(({ name }) => {
    const sizeFolder = `${projectPath}/${output}/${name}`;

    if (!fs.existsSync(sizeFolder)) {
      shell.mkdir('-p', sizeFolder);
      screenshotsLogger.successCompact(`Created ${sizeFolder}`);
    }
  });

  screenshotsLogger.step(1, 'Resizing screenshots');

  const files = fs.readdirSync(input);

  for (const fileName of files) {
    const extension = path.extname(fileName);
    if (!['.png', '.jpg', '.jpeg', '.webp'].includes(extension)) {
      continue;
    }

    for (const size of sizes) {
      const resolution = orientation === 'landscape' ? size.resolution : size.resolution.split('x').reverse().join('x');

      const outputFileName = `${fileName.split(extension)[0]}-${resolution}${size.extension || extension}`;
      const outputPath = `${output}/${size.name}/${outputFileName}`;

      const resized = runMagick(
        [
          quote(`${input}/${fileName}`),
          '-resize',
          quote(`${resolution}^`),
          '-gravity',
          'center',
          '-extent',
          quote(resolution),
          quote(outputPath),
        ],
        screenshotsLogger,
      );

      if (!resized) {
        screenshotsLogger.error(`Aborting: could not resize ${fileName} to ${size.name} (${resolution})`);
        return false;
      }

      screenshotsLogger.successCompact(`${fileName} → ${size.name} (${resolution})`);
    }
  }

  screenshotsLogger.done('Screenshots generated');
  return true;
};

// -----------------------------------------------------------------------------

export default generateScreenshots;
