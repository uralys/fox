// -----------------------------------------------------------------------------
// generates the iOS launch screen storyboard images from a base image
// requires ImageMagick, see docs/install.md
// -----------------------------------------------------------------------------
// Godot consumes them through the export preset keys
// `storyboard/custom_image@2x`, `storyboard/custom_image@3x` and
// `storyboard/use_launch_screen_storyboard=true`, see docs/generate.md
// -----------------------------------------------------------------------------

import fs from 'fs';
import path from 'path';
import {ensureImageMagick, quote, runMagick} from './imagemagick.js';
import {splashLogger} from './logger.js';

// -----------------------------------------------------------------------------

const IOS_PLATFORM = 'ios';

const DEFAULT_BUNDLE_ID = 'default';

const DEFAULT_BACKGROUND_COLOR = '#181818';

// The storyboard only needs the two densest images: iOS scales them down for
// every other device, which is why the 11 legacy launch images are gone.
const STORYBOARD_IMAGES = [
  {name: 'splash@2x.png', size: '1170x2532'},
  {name: 'splash@3x.png', size: '1290x2796'}
];

// -----------------------------------------------------------------------------

const resolveBundleIds = (config, bundles) => {
  const declared = bundles || config.bundles;
  const ids = declared ? Object.keys(declared) : [];

  return ids.length > 0 ? ids : [DEFAULT_BUNDLE_ID];
};

// -----------------------------------------------------------------------------

const createStoryboardImage = (inputFile, backgroundColor, outputPath) => (image) => {
  const created = runMagick(
    [
      quote(inputFile),
      '-gravity',
      'center',
      '-background',
      quote(backgroundColor),
      '-extent',
      quote(image.size),
      quote(path.join(outputPath, image.name))
    ],
    splashLogger
  );

  if (!created) {
    splashLogger.error(`Aborting: could not generate ${image.name} (${image.size})`);
    return false;
  }

  splashLogger.successCompact(`${image.name} ${image.size}`);
  return true;
};

// -----------------------------------------------------------------------------

const generateSplashscreens = (config, bundles) => {
  const {input, output, backgroundColor = DEFAULT_BACKGROUND_COLOR} = config;

  if (!ensureImageMagick(splashLogger)) {
    return false;
  }

  if (!fs.existsSync(input)) {
    splashLogger.error(`Input does not exist: ${input}`);
    return false;
  }

  const bundleIds = resolveBundleIds(config, bundles);

  splashLogger.log('Generating launch screen storyboard images');
  splashLogger.data({input, output, backgroundColor, bundles: bundleIds.join(', ')});

  let created = 0;

  for (const [index, bundleId] of bundleIds.entries()) {
    const outputPath = path.join(output, bundleId, IOS_PLATFORM);
    splashLogger.step(index, `${bundleId} → ${outputPath}`);

    fs.mkdirSync(outputPath, {recursive: true});

    const applyConversion = createStoryboardImage(input, backgroundColor, outputPath);

    if (!STORYBOARD_IMAGES.every(applyConversion)) {
      return false;
    }

    created += STORYBOARD_IMAGES.length;
  }

  splashLogger.done(`${created} storyboard images created`);
  return true;
};

// -----------------------------------------------------------------------------

export default generateSplashscreens;
