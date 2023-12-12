// -----------------------------------------------------------------------------
// generates splashscreens from a base image
// requires https://www.imagemagick.org/script/index.php
// to enable "convert" command
// OSX: brew install imagemagick
// -----------------------------------------------------------------------------

import chalk from 'chalk';
import shell from 'shelljs';

// -----------------------------------------------------------------------------

const LANDSCAPE_SIZES = ['2436x1125', '2208x1242', '1024x768', '2048x1536'];

const PORTRAIT_SIZES = [
  '640x960',
  '640x1136',
  '750x1334',
  '1125x2436',
  '768x1024',
  '1536x2048',
  '1242x2208'
];

// -----------------------------------------------------------------------------

const convert = (inputFile, backgroundColor, outputPath) => (size) => {
  console.log(`   ${chalk.magenta.italic(size)}`);
  shell.exec(
    `convert ${inputFile} -gravity center -background '${backgroundColor}' -extent ${size} "${outputPath}/splashscreen-${size}.png"`
  );
};

// -----------------------------------------------------------------------------

const generateSplashscreens = (config) => {
  const {input, output, backgroundColor = '#181818'} = config;
  console.log(`---> generating ${chalk.blue.bold('splashscreens')}...`);

  const applyConversion = convert(input, backgroundColor, output);

  console.log(` > creating ${chalk.magenta.italic('landscape')} launch screens...`);
  LANDSCAPE_SIZES.forEach(applyConversion);

  console.log(` > creating ${chalk.magenta.italic('portrait')}  launch screens...`);
  PORTRAIT_SIZES.forEach(applyConversion);

  console.log(
    `\nCreated ${chalk.green(
      LANDSCAPE_SIZES.length + PORTRAIT_SIZES.length
    )} splashscreens ${chalk.green('successfully')}.`
  );
  console.log(`--->  ${chalk.blue.bold('output:')} ${output}`);
};

// -----------------------------------------------------------------------------

export default generateSplashscreens;
