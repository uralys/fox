// -----------------------------------------------------------------------------
// resize screenshots to match store requirements
// requires https://www.imagemagick.org/script/index.php
// to enable "convert" command
// OSX: brew install imagemagick
// -----------------------------------------------------------------------------

import fs from 'fs';
import path from 'path';
import shell from 'shelljs';
import {screenshotsLogger} from './logger.js';

// -----------------------------------------------------------------------------

const generateScreenshots = (config) => {
  const {orientation, input, output, sizes} = config;
  const projectPath = path.resolve(process.cwd(), './');

  screenshotsLogger.log('Generating screenshots');
  screenshotsLogger.data({orientation, input, output});

  screenshotsLogger.step(0, 'Verifying folders');

  sizes.forEach(({name}) => {
    const sizeFolder = `${projectPath}/${output}/${name}`;

    if (!fs.existsSync(sizeFolder)) {
      shell.mkdir('-p', sizeFolder);
      screenshotsLogger.successCompact(`Created ${sizeFolder}`);
    }
  });

  screenshotsLogger.step(1, 'Resizing screenshots');

  const files = fs.readdirSync(input);

  files.forEach((fileName) => {
    const extension = path.extname(fileName);
    if (!['.png', '.jpg', '.jpeg', '.webp'].includes(extension)) {
      return;
    }

    sizes.forEach((size) => {
      const resolution = orientation === 'landscape' ? size.resolution : size.resolution.split('x').reverse().join('x');

      const outputFileName = `${fileName.split(extension)[0]}-${resolution}${size.extension || extension}`;
      const outputPath = `${output}/${size.name}/${outputFileName}`;

      shell.exec(
        `convert ${input}/${fileName} -resize ${resolution}^ -gravity center -extent ${resolution} "${outputPath}"`
      );

      screenshotsLogger.successCompact(`${fileName} → ${size.name} (${resolution})`);
    });
  });

  screenshotsLogger.done('Screenshots generated');
};

// -----------------------------------------------------------------------------

export default generateScreenshots;
