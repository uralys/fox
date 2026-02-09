// -----------------------------------------------------------------------------
// generates splashscreens from a base image
// requires https://www.imagemagick.org/script/index.php
// to enable "convert" command
// OSX: brew install imagemagick
// -----------------------------------------------------------------------------

import shell from 'shelljs';
import {splashLogger} from './logger.js';

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
  shell.exec(
    `convert ${inputFile} -gravity center -background '${backgroundColor}' -extent ${size} "${outputPath}/splashscreen-${size}.png"`
  );
  splashLogger.successCompact(size);
};

// -----------------------------------------------------------------------------

const generateSplashscreens = (config) => {
  const {input, output, backgroundColor = '#181818'} = config;

  splashLogger.log('Generating splashscreens');
  splashLogger.data({input, output, backgroundColor});

  const applyConversion = convert(input, backgroundColor, output);

  splashLogger.step(0, 'Creating landscape launch screens');
  LANDSCAPE_SIZES.forEach(applyConversion);

  splashLogger.step(1, 'Creating portrait launch screens');
  PORTRAIT_SIZES.forEach(applyConversion);

  splashLogger.done(`${LANDSCAPE_SIZES.length + PORTRAIT_SIZES.length} splashscreens created`);
};

// -----------------------------------------------------------------------------

export default generateSplashscreens;
