// -----------------------------------------------------------------------------
// generates splashscreens from a base image
// requires ImageMagick, see docs/install.md
// -----------------------------------------------------------------------------

import {ensureImageMagick, quote, runMagick} from './imagemagick.js';
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

const resizer = (inputFile, backgroundColor, outputPath) => (size) => {
  const created = runMagick(
    [
      quote(inputFile),
      '-gravity',
      'center',
      '-background',
      quote(backgroundColor),
      '-extent',
      quote(size),
      quote(`${outputPath}/splashscreen-${size}.png`)
    ],
    splashLogger
  );

  if (!created) {
    splashLogger.error(`Aborting: could not generate the ${size} splashscreen`);
    return false;
  }

  splashLogger.successCompact(size);
  return true;
};

// -----------------------------------------------------------------------------

const generateSplashscreens = (config) => {
  const {input, output, backgroundColor = '#181818'} = config;

  if (!ensureImageMagick(splashLogger)) {
    return false;
  }

  splashLogger.log('Generating splashscreens');
  splashLogger.data({input, output, backgroundColor});

  const applyConversion = resizer(input, backgroundColor, output);

  splashLogger.step(0, 'Creating landscape launch screens');
  if (!LANDSCAPE_SIZES.every(applyConversion)) {
    return false;
  }

  splashLogger.step(1, 'Creating portrait launch screens');
  if (!PORTRAIT_SIZES.every(applyConversion)) {
    return false;
  }

  splashLogger.done(`${LANDSCAPE_SIZES.length + PORTRAIT_SIZES.length} splashscreens created`);
  return true;
};

// -----------------------------------------------------------------------------

export default generateSplashscreens;
