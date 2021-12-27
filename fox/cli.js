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

// -----------------------------------------------------------------------------

const GENERATE_ICONS = 'generate:icons';
const GENERATE_SPLASHSCREENS = 'generate:splashscreens';

// -----------------------------------------------------------------------------

const commands = [GENERATE_ICONS, GENERATE_SPLASHSCREENS];
const commandMessage = `choose one command: [${commands.join(', ')}]`;

// -----------------------------------------------------------------------------

const DEFAULT_CONFIG_FILE = 'fox/_commands/default.config.json';
const CONFIG_FILE = 'fox.config.json';

const getConfig = (command) => {
  let config;

  try {
    const configPath = path.resolve(process.cwd(), `./${CONFIG_FILE}`);
    console.log(`---> using ${chalk.blue.bold(CONFIG_FILE)}`);
    config = require(configPath);
  } catch (e) {
    console.log(chalk.yellow(`No file "${CONFIG_FILE}" was found\nUsing default setup.`));
    const defaultConfigPath = path.resolve(process.cwd(), `./${DEFAULT_CONFIG_FILE}`);
    config = require(defaultConfigPath);
  }

  console.log({[command]: config[command]});
  return config[command];
};

// -----------------------------------------------------------------------------

const checkIO = (subconfig) => {
  const {inputFile, outputPath} = subconfig;
  if (!inputFile) {
    console.log(`${chalk.red.bold('inputFile not provided')} in your config.`);
    return null;
  }

  if (!outputPath) {
    console.log(`${chalk.red.bold('outputPath not provided')} in your config.`);
    return null;
  }

  const projectPath = path.resolve(process.cwd(), './');
  const input = `${projectPath}/${inputFile}`;
  const output = `${projectPath}/${outputPath}`;

  console.log(`---> ${chalk.blue.bold('IO')}`);
  console.log({input, output});

  if (!fs.existsSync(input)) {
    console.log(`${chalk.red.bold('input does not exist')}, verify your inputFile.`);
    return null;
  }

  if (!fs.existsSync(output)) {
    shell.mkdir(output);
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
  var {input, output} = checkIO(config);

  switch (command) {
    case GENERATE_ICONS: {
      generateIcons(input, output);
      break;
    }
    case GENERATE_SPLASHSCREENS: {
      generateSplashscreens(input, output, config.backgroundColor);
      break;
    }
    default: {
      console.log(command);
      console.log(chalk.red.bold('🔴 not handled'));
    }
  }
};

// -----------------------------------------------------------------------------

const argv = yargs(process.argv.slice(2))
  .usage('Usage: fox <command> [options]')
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

try {
  cli(argv);
} catch (e) {
  console.log(chalk.red.bold('🔴 failed'));
}
