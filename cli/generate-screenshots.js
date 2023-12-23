// -----------------------------------------------------------------------------
// resize screenshots to match store requirements
// requires https://www.imagemagick.org/script/index.php
// to enable "convert" command
// OSX: brew install imagemagick
// -----------------------------------------------------------------------------

import chalk from 'chalk';
import fs from 'fs';
import path from 'path';
import shell from 'shelljs';

// -----------------------------------------------------------------------------

const generateScreenshots = (config) => {
  const {orientation, input, output, sizes} = config;
  const projectPath = path.resolve(process.cwd(), './');

  console.log(`\n⚙️  veryfing folders ...`);

  sizes.forEach(({name}) => {
    const sizeFolder = `${projectPath}/${output}/${name}`;

    if (!fs.existsSync(sizeFolder)) {
      shell.mkdir('-p', sizeFolder);
      console.log(`✅ created ${sizeFolder}`);
    }
  })


  console.log(`\n⚙️  resizing ${chalk.blue.bold('screenshots')}...`);
  console.log(`⚙️  orientation: ${chalk.blue.bold(orientation)}`);

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

      console.log(`\n > ${chalk.magenta.italic(fileName)} | ${chalk.magenta.italic(size.name)} --> ${outputPath}`);

      shell.exec(
        `convert ${input}/${fileName} -resize ${resolution}^ -gravity center -extent ${resolution} "${outputPath}"`
      );

      console.log(`Resized images to ${resolution} ${chalk.green('successfully')}.`);
    });
  });
};

// -----------------------------------------------------------------------------

export default generateScreenshots;
