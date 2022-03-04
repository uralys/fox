// -----------------------------------------------------------------------------
// resize screenshots to match store requirements
// requires https://www.imagemagick.org/script/index.php
// to enable "convert" command
// OSX: brew install imagemagick
// -----------------------------------------------------------------------------

const chalk = require('chalk');
const fs = require('fs');
const path = require('path');
const shell = require('shelljs');

// -----------------------------------------------------------------------------

const generateScreenshots = (config) => {
  const {input, output, sizes = ['2560x1600']} = config;
  console.log(`⚙️  resizing ${chalk.blue.bold('screenshots')}...`);

  const files = fs.readdirSync(input);

  files.forEach((fileName) => {
    const extension = path.extname(fileName);
    if (!['.png', '.jpg', '.jpeg'].includes(extension)) {
      return;
    }

    sizes.forEach((size) => {
      const outputFileName = `${fileName.split(extension)[0]}-${size}${extension}`;
      console.log(` > ${chalk.magenta.italic(fileName)} --> ${output}/${outputFileName}`);

      shell.exec(
        `convert ${input}/${fileName} -resize ${size}^ -gravity center -extent ${size} "${output}/${outputFileName}"`
      );

      console.log(`\n Resized images to ${size} ${chalk.green('successfully')}.`);
    });
  });
};

// -----------------------------------------------------------------------------

module.exports = generateScreenshots;
