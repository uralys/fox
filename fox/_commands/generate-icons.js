// -----------------------------------------------------------------------------
// generates icons from a base image
// requires https://www.imagemagick.org/script/index.php
// to enable "convert" command
// OSX: brew install imagemagick
// -----------------------------------------------------------------------------
// based on 🍒 https://github.com/chrisdugne/cherry/blob/master/prepare-icons.sh
// -----------------------------------------------------------------------------

const chalk = require('chalk');
const shell = require('shelljs');

// -----------------------------------------------------------------------------

// https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/AppIconType.html
const SIZES = [
  '20x20',
  '29x29',
  '40x40',
  '58x58',
  '60x60',
  '76x76',
  '80x80',
  '87x87',
  '120x120',
  '152x152',
  '167x167',
  '180x180',
  '512x512',
  '1024x1024'
];

// -----------------------------------------------------------------------------

const generateIcons = (input, output) => {
  console.log(`---> generating ${chalk.blue.bold('icons')}...`);

  SIZES.forEach((size) => {
    console.log(` > ${chalk.magenta.italic(size)}`);
    shell.exec(`convert ${input} -resize '${size}' -unsharp 1x4 "${output}/icon-${size}.png"`);
  });

  console.log(`\n Created ${chalk.green(SIZES.length)} icons ${chalk.green('successfully')}.`);
};

// -----------------------------------------------------------------------------

module.exports = generateIcons;
