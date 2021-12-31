#!/usr/bin/env node
// -----------------------------------------------------------------------------

const chalk = require('chalk');
const fs = require('fs');
const path = require('path');
const shell = require('shelljs');
const yargs = require('yargs');

const pkg = require('../package.json');

// -----------------------------------------------------------------------------

const generateIcons = require('./generate-icons');
const generateSplashscreens = require('./generate-splashscreens');
const generateScreenshots = require('./generate-screenshots');
const runGame = require('./run-game');

// -----------------------------------------------------------------------------

const GENERATE_ICONS = 'generate:icons';
const GENERATE_SPLASHSCREENS = 'generate:splashscreens';
const GENERATE_SCREENSHOTS = 'generate:screenshots';

const RUN_EDITOR = 'run:editor';
const RUN_GAME = 'run:game';

// -----------------------------------------------------------------------------

const commands = [
  GENERATE_ICONS,
  GENERATE_SCREENSHOTS,
  GENERATE_SPLASHSCREENS,
  RUN_EDITOR,
  RUN_GAME
];
const commandMessage = `choose a command above, example:\n${chalk.italic(`fox ${RUN_EDITOR}`)}`;

// -----------------------------------------------------------------------------

const DEFAULT_CONFIG_FILE = 'fox/default.config.json';
const CONFIG_FILE = 'fox.config.json';

const defaultConfigPath = path.resolve(process.cwd(), `${DEFAULT_CONFIG_FILE}`);

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

    if (!config[command]) {
      console.log(chalk.yellow(`No config for "${command}" was found\nUsing default config.`));
      config = defaultConfig;
    }
  } catch (e) {
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

  console.log(chalk.bold.green(`Fox CLI v${pkg.version}`));
  console.log(`🦊 ${chalk.italic('started command')} ${chalk.cyan(command)}`);
  var config = getConfig(command);

  // -------- Godot commands

  switch (command) {
    case RUN_EDITOR: {
      console.log('----------------------------');
      console.log(`🦊 ${chalk.italic('opening Godot editor')}`);
      var {godotPath, resolution, position} = config;
      shell.exec(`${godotPath} -e -v --windowed --resolution ${resolution} --position ${position}`);
      return;
    }
    case RUN_GAME: {
      runGame(config);
      return;
    }
  }

  // -------- IO commands

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

  return true;
};

// -----------------------------------------------------------------------------

const argv = yargs(process.argv.splice(2))
  .usage('Usage: fox <command> [options]')
  .command(RUN_EDITOR, 'open Godot Editor')
  .command(RUN_GAME, 'start your game to debug')
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
  var result = cli(argv);
  if (result) {
    console.log(`🦊 ${chalk.italic('done.')}`);
  }
} catch (e) {
  console.log(e);
  console.log(chalk.red.bold('🔴 failed'));
}
