// -----------------------------------------------------------------------------
// generates icons from a base image
// requires https://www.imagemagick.org/script/index.php
// to enable "convert" command
// OSX: brew install imagemagick
// -----------------------------------------------------------------------------
// based on 🍒 https://github.com/chrisdugne/cherry/blob/master/prepare-icons.sh
// -----------------------------------------------------------------------------

const chalk = require('chalk');
const path = require('path');
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

const generateIcons = () => {
  console.log(chalk.green('🦊 generating icons...'));

  // ---------
  const projectPath = path.resolve(process.cwd(), './');
  const inputFile = `${projectPath}/_release/images/icon-square-1200x1200.png`;
  const outputPath = `${projectPath}/_release/generated`;

  console.log({inputFile, outputPath});

  SIZES.forEach((size) => {
    shell.exec(
      `convert ${inputFile} -resize '${size}' -unsharp 1x4 "${outputPath}/icon-${size}.png"`
    );
  });

  // ---------
  console.log(`Created ${chalk.green(SIZES.length)} icons successfully.`);
};

// -----------------------------------------------------------------------------

module.exports = generateIcons;
