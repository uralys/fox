// -----------------------------------------------------------------------------
// generates icons from a base image
// requires https://www.imagemagick.org/script/index.php
// to enable "convert" command
// OSX: brew install imagemagick
// -----------------------------------------------------------------------------
// based on 🍒 https://github.com/chrisdugne/cherry/blob/master/prepare-icons.sh
// -----------------------------------------------------------------------------

const chalk = require('chalk');
const fs = require('fs');
const shell = require('shelljs');

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
  '256x256',
  '512x512',
  '1024x1024'
];

// -----------------------------------------------------------------------------

const generateIcons = (config) => {
  console.log(`---> generating ${chalk.blue.bold('icons')}...`);
  const {input, output, base, background, foreground, desktop} = config;

  if (!fs.existsSync(`${input}/${base}`)) {
    console.log(
      `${chalk.bold('input')} base ${chalk.red.bold('does not exist')}, please check your config`
    );
    return null;
  }

  SIZES.forEach((size) => {
    console.log(` > ${chalk.magenta.italic(size)}`);
    shell.exec(
      `convert ${input}/${base} -resize '${size}' -unsharp 1x4 "${output}/icon-${size}.png"`
    );
  });

  console.log(`\n > copying ${chalk.blue.bold('base')} icon`);
  shell.cp(`${input}/${base}`, `${output}/${base}`);

  if (background) {
    console.log(`\n > copying ${chalk.blue.bold('android adaptive')} elements`);
    shell.cp(`${input}/${background}`, `${output}/${background}`);
    shell.cp(`${input}/${foreground}`, `${output}/${foreground}`);
  }

  if (desktop) {
    console.log(`\n > copying ${chalk.blue.bold('desktop')} icon`);
    shell.cp(`${input}/${desktop}`, `${output}/${desktop}`);
  }

  console.log(`\n Created ${chalk.green(SIZES.length)} icons ${chalk.green('successfully')}.`);
};

// -----------------------------------------------------------------------------

module.exports = generateIcons;
