// -----------------------------------------------------------------------------
// generates splashscreens from a base image
// requires https://www.imagemagick.org/script/index.php
// to enable "convert" command
// OSX: brew install imagemagick
// -----------------------------------------------------------------------------

const chalk = require('chalk');
const path = require('path');
const shell = require('shelljs');

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

const convert = (inputFile, color, outputPath) => (size) => {
  shell.exec(
    `convert ${inputFile} -gravity center -background '${color}' -extent ${size} "${outputPath}/splashscreen-${size}.png"`
  );
};

// -----------------------------------------------------------------------------

const generateSplashscreens = () => {
  console.log(chalk.green('🦊 generating splashscreens...'));

  // ---------
  const projectPath = path.resolve(process.cwd(), './');
  const inputFile = `${projectPath}/_release/images/base-splashscreen.png`;
  const outputPath = `${projectPath}/_release/generated`;
  const color = '#181818';

  console.log({inputFile, outputPath});

  const applyConversion = convert(inputFile, color, outputPath);

  console.log('> creating landscape launch screens...');
  LANDSCAPE_SIZES.forEach(applyConversion);

  console.log('> creating portrait launch screens...');
  PORTRAIT_SIZES.forEach(applyConversion);

  // ---------
  console.log(
    `Created ${chalk.green(
      LANDSCAPE_SIZES.length + PORTRAIT_SIZES.length
    )} splashscreens successfully.`
  );
};

// -----------------------------------------------------------------------------

module.exports = generateSplashscreens;
