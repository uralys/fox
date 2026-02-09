// -----------------------------------------------------------------------------
// generates icons from a base image
// requires https://www.imagemagick.org/script/index.php
// to enable "convert" command
// OSX: brew install imagemagick
// -----------------------------------------------------------------------------
// based on 🍒 https://github.com/chrisdugne/cherry/blob/master/prepare-icons.sh
// -----------------------------------------------------------------------------

import fs from 'fs';
import shell from 'shelljs';
import {iconsLogger} from './logger.js';

// -----------------------------------------------------------------------------

// https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/AppIconType.html
const SIZES = [
  '20x20',
  '29x29',
  '32x32',
  '40x40',
  '58x58',
  '60x60',
  '64x64',
  '76x76',
  '80x80',
  '87x87',
  '120x120',
  '128x128',
  '152x152',
  '167x167',
  '180x180',
  '192x192',
  '256x256',
  '512x512',
  '1024x1024'
];

// -----------------------------------------------------------------------------

const generateIcons = (config) => {
  const {input, output, base, background, foreground, desktop} = config;

  if (!fs.existsSync(`${input}/${base}`)) {
    iconsLogger.error(`Input base does not exist: ${input}/${base}`);
    return null;
  }

  iconsLogger.log(`Generating from ${base}`);
  iconsLogger.data({input: `${input}/${base}`, output});

  SIZES.forEach((size) => {
    shell.exec(
      `convert ${input}/${base} -resize '${size}' -unsharp 1x4 "${output}/icon-${size}.png"`
    );
    iconsLogger.successCompact(size);
  });

  iconsLogger.step(0, 'Copying base icon');
  shell.cp(`${input}/${base}`, `${output}/${base}`);

  if (background) {
    iconsLogger.step(1, 'Copying android adaptive elements');
    shell.cp(`${input}/${background}`, `${output}/${background}`);
    shell.cp(`${input}/${foreground}`, `${output}/${foreground}`);
  }

  if (desktop) {
    iconsLogger.step(2, 'Copying desktop icon');
    shell.cp(`${input}/${desktop}`, `${output}/${desktop}`);
  }

  iconsLogger.done(`${SIZES.length} icons created`);
};

// -----------------------------------------------------------------------------

export default generateIcons;
