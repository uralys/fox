#!/usr/bin/env node

const chalk = require('chalk');
// const path = require('path');
const yargs = require('yargs');

const pkg = require('../package.json');

// -----------------------------------------------------------------------------

const generateIcons = require('./_commands/generate-icons');
const generateSplashscreens = require('./_commands/generate-splashscreens');

// -----------------------------------------------------------------------------

const GENERATE_ICONS = 'generate-icons';
const GENERATE_SPLASHSCREENS = 'generate-splashscreens';

const commands = [GENERATE_ICONS, GENERATE_SPLASHSCREENS];
const commandMessage = `choose one command: [${commands}]`;

// -----------------------------------------------------------------------------

const foxCLI = (args) => {
  const command = argv._[0];
  if (!commands.includes(command)) {
    yargs.showHelp();
    return;
  }

  switch (command) {
    case GENERATE_ICONS: {
      generateIcons();
      break;
    }
    case GENERATE_SPLASHSCREENS: {
      generateSplashscreens();
      break;
    }
    default: {
      console.log(command);
      console.log('🔴 not handled');
    }
  }
};

// -----------------------------------------------------------------------------

const argv = yargs(process.argv.slice(2))
  .usage('🦊 Usage: fox <command> [options]')
  .command(GENERATE_ICONS, 'generate icons, using a base 1200x1200 image')
  .command(
    GENERATE_SPLASHSCREENS,
    'generate splashscreens, extending a background color from a centered base image'
  )
  .demandCommand(1, 1, commandMessage, commandMessage)
  .help('h')
  .version(pkg.version)
  .alias('version', 'v')
  .epilog(
    `${chalk.bold.green(`🦊 Fox CLI v${pkg.version}`)}
    Documentation: https://github.com/uralys/fox
    Icons, splashscreens and screenshots commands require ImageMagick https://imagemagick.org/index.php`
  ).argv;

// -----------------------------------------------------------------------------

foxCLI(argv);
