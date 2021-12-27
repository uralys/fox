#!/usr/bin/env node
// -----------------------------------------------------------------------------

const chalk = require('chalk');
const fs = require('fs');
const path = require('path');
const shell = require('shelljs');
const yargs = require('yargs');

const pkg = require('../package.json');

// -----------------------------------------------------------------------------

const generateIcons = require('./_commands/generate-icons');
const generateSplashscreens = require('./_commands/generate-splashscreens');
const generateScreenshots = require('./_commands/generate-screenshots');

// -----------------------------------------------------------------------------

const GENERATE_ICONS = 'generate:icons';
const GENERATE_SPLASHSCREENS = 'generate:splashscreens';
const GENERATE_SCREENSHOTS = 'generate:screenshots';

const RUN_EDITOR = 'run:editor';

// -----------------------------------------------------------------------------

const commands = [GENERATE_ICONS, GENERATE_SCREENSHOTS, GENERATE_SPLASHSCREENS, RUN_EDITOR];
const commandMessage = `choose a command above, example:\n${chalk.italic(`fox ${RUN_EDITOR}`)}`;

// -----------------------------------------------------------------------------

const DEFAULT_CONFIG_FILE = 'fox/_commands/default.config.json';
const CONFIG_FILE = 'fox.config.json';

const defaultConfigPath = path.resolve(process.cwd(), `./${DEFAULT_CONFIG_FILE}`);

let defaultConfig;

try {
  defaultConfig = require(defaultConfigPath);
} catch (e) {
  console.log(
    chalk.red.bold('🔴 failed:'),
    chalk.blue.bold(process.cwd()),
    'is not a project using Fox'
  );
  return;
}

// -----------------------------------------------------------------------------

const getConfig = (command) => {
  let config;

  try {
    const configPath = path.resolve(process.cwd(), `./${CONFIG_FILE}`);
    console.log(`---> using ${chalk.blue.bold(CONFIG_FILE)}`);
    config = require(configPath);
  } catch (e) {
    console.log(chalk.yellow(`No file "${CONFIG_FILE}" was found\nUsing default config.`));
    config = defaultConfig;
  }

  console.log({[command]: config[command]});
  return config[command];
};

// -----------------------------------------------------------------------------

const checkIO = (subconfig, defaultSubconfig) => {
  const requirements = Object.keys(defaultSubconfig);

  requirements.forEach((requirement) => {
    const value = subconfig[requirement];
    if (!value) {
      console.log(`${chalk.red.bold(`${requirement} not provided`)} in your config.`);
      return null;
    }
  });

  const projectPath = path.resolve(process.cwd(), './');
  const input = `${projectPath}/${subconfig.input}`;
  const output = `${projectPath}/${subconfig.output}`;

  console.log(`---> ${chalk.blue.bold('IO')}`);
  console.log({input, output});

  if (!fs.existsSync(input)) {
    console.log(
      `${chalk.bold('input')} path ${chalk.red.bold('does not exist')}, please check your config`
    );
    return null;
  }

  if (!fs.existsSync(output)) {
    shell.mkdir('-p', output);
    console.log('✅ created output.');
  }

  return {input, output};
};

// -----------------------------------------------------------------------------

const cli = (args) => {
  const command = argv._[0];
  if (!commands.includes(command)) {
    yargs.showHelp();
    return;
  }

  console.log(chalk.cyan('🦊 running', command));
  var config = getConfig(command);
  var {input, output} = checkIO(config, defaultConfig[command]);

  switch (command) {
    case GENERATE_ICONS: {
      generateIcons(input, output);
      break;
    }
    case GENERATE_SPLASHSCREENS: {
      generateSplashscreens(input, output, config.backgroundColor);
      break;
    }
    case GENERATE_SCREENSHOTS: {
      generateScreenshots(input, output);
      break;
    }
    default: {
      console.log(command);
      console.log(chalk.red.bold('🔴 not handled'));
    }
  }
};

// -----------------------------------------------------------------------------

const argv = yargs(process.argv.splice(2))
  .usage('Usage: fox <command> [options]')
  .command(GENERATE_ICONS, 'generate icons, using a base 1200x1200 image')
  .command(
    GENERATE_SPLASHSCREENS,
    'generate splashscreens, extending a background color from a centered base image'
  )
  .command(
    GENERATE_SCREENSHOTS,
    'resize all images in a folder to 2560x1600, to match store requirements'
  )
  .demandCommand(1, 1, commandMessage, commandMessage)
  .help('h')
  .version(pkg.version)
  .alias('version', 'v').epilog(`${chalk.bold.green(`🦊 Fox CLI v${pkg.version}`)}
    Documentation: https://github.com/uralys/fox
    Icons, splashscreens and screenshots commands require ImageMagick https://imagemagick.org/index.php`).argv;

// -----------------------------------------------------------------------------

try {
  cli(argv);
} catch (e) {
  console.log(chalk.red.bold('🔴 failed'));
}
