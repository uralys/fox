#!/usr/bin/env node --no-warnings
// -----------------------------------------------------------------------------

import chalk from 'chalk';
import fs from 'fs';
import path from 'path';
import shell from 'shelljs';
import { spawn } from 'child_process';
import yargsFactory from 'yargs';

import pkg from '../package.json' with { type: 'json' };

// -----------------------------------------------------------------------------

import generateIcons from './generate-icons.js';
import generateSplashscreens from './generate-splashscreens.js';
import generateScreenshots from './generate-screenshots.js';
import exportBundle from './bundler/export.js';
import { readPresets } from './bundler/read-presets.js';
import switchBundle from './bundler/switch.js';
import runGame from './run-game.js';

// -----------------------------------------------------------------------------

const EXPORT = 'export';
const SWITCH = 'switch';

const GENERATE_ICONS = 'generate:icons';
const GENERATE_SPLASHSCREENS = 'generate:splashscreens';
const GENERATE_SCREENSHOTS = 'generate:screenshots';
const UPDATE_PO_FILES = 'update-po-files';

const RUN_EDITOR = 'run:editor';
const RUN_GAME = 'run:game';

// -----------------------------------------------------------------------------

const commands = [
  EXPORT,
  SWITCH,
  GENERATE_ICONS,
  GENERATE_SCREENSHOTS,
  GENERATE_SPLASHSCREENS,
  UPDATE_PO_FILES,
  RUN_EDITOR,
  RUN_GAME
];

const commandMessage = `choose a command above, example:\n${chalk.italic(`fox ${RUN_EDITOR}`)}`;

// -----------------------------------------------------------------------------

const DEFAULT_CONFIG_FILE = 'fox/default.config.json';
const CONFIG_FILE = 'fox.config.json';

// -----------------------------------------------------------------------------

const getSettings = async (command, defaultConfig) => {
  let config;
  const configPath = path.resolve(process.cwd(), `./${CONFIG_FILE}`);

  try {
    console.log(`⚙️  reading ${chalk.blue.bold(CONFIG_FILE)}`);
    config = (await import(configPath, { with: { type: "json" } })).default;

    if (!config[command] && defaultConfig[command]) {
      console.log(chalk.green(`Using default config for command "${command}"`));
      config = defaultConfig;
    }
  } catch (e) {
    console.log(`could not find ${chalk.blue.bold(CONFIG_FILE)} > ${chalk.green(`Using default config for command "${command}"`)}`);
    config = defaultConfig;
    return;
  }

  return {
    config: { ...defaultConfig[command], ...config[command] },
    core: { ...defaultConfig.core, ...config.core },
    bundles: config.bundles
  };
};

// -----------------------------------------------------------------------------

const verifyConfig = (config, defaultConfig) => {
  const requirements = Object.keys(defaultConfig);

  requirements.forEach((requirement) => {
    const value = config[requirement];
    if (!value) {
      const message = `${chalk.red.bold(`${requirement} not provided`)} in your config.`;
      console.log(message);
      throw new Error(message);
    }
  });

  if (config.output) {
    const projectPath = path.resolve(process.cwd(), './');
    const output = `${projectPath}/${config.output}`;

    console.log(`⚙️  ${chalk.blue.bold('verifying output path')}`);
    console.log(output);

    if (!fs.existsSync(output)) {
      shell.mkdir('-p', output);
      console.log('✅ created output.');
    }
  }
};

// -----------------------------------------------------------------------------

const cli = async (yargs, params) => {
  const defaultConfigPath = path.resolve(process.cwd(), `${DEFAULT_CONFIG_FILE}`);

  let defaultConfig;

  try {
    defaultConfig = (await import(defaultConfigPath, { with: { type: "json" } })).default;
  } catch (e) {
    console.log(
      chalk.red.bold('🔴 failed:'),
      chalk.blue.bold(process.cwd()),
      'is not a project using Fox'
    );
    return;
  }

  // --------

  const command = yargs.argv._[0];

  if (!commands.includes(command)) {
    yargs.showHelp();
    return;
  }

  // --------

  console.log(chalk.bold.green(`Fox CLI v${pkg.version}`));
  console.log(`🦊 ${chalk.italic('started command')} ${chalk.cyan(command)}`);
  const settings = await getSettings(command, defaultConfig);

  if (!settings) {
    return;
  }

  const { core, config, bundles } = settings;

  // -------- Godot commands

  switch (command) {
    case RUN_EDITOR: {
      console.log('----------------------------');
      console.log(`🦊 ${chalk.italic('opening Godot editor')}`);
      const { resolution, position } = config;

      // '-e' runs editor
      const editorProcess = spawn(
        core.godot,
        ['-e', '--windowed', '--resolution', resolution, '--position', position],
        { stdio: [process.stdin, process.stdout, process.stderr] }
      );

      editorProcess.on('close', () => {
        console.log(`🦊 ${chalk.italic('bye!')}`);
      });

      return;
    }
    case RUN_GAME: {
      runGame(core.godot, params, config);
      return;
    }
    case EXPORT: {
      exportBundle(settings);
      return;
    }
    case SWITCH: {
      const presets = readPresets();
      switchBundle(settings, presets);
      return;
    }
  }

  // -------- IO commands

  verifyConfig(config, defaultConfig[command]);

  switch (command) {
    case GENERATE_ICONS: {
      generateIcons(config);
      break;
    }
    case GENERATE_SPLASHSCREENS: {
      generateSplashscreens(config);
      break;
    }
    case UPDATE_PO_FILES: {
      const { poFiles, potTemplate } = config;
      console.log(`⚙️  using ${chalk.blue.bold('msgmerge')} on your .po files`);
      shell.exec(`for file in ${poFiles}; do echo \${file} ; msgmerge --backup=off --update \${file} ${potTemplate}; done`);
      break;
    }
    case GENERATE_SCREENSHOTS: {
      generateScreenshots(config);
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

const execute = async () => {
  const params = process.argv.slice(3);

  const yargs = yargsFactory(process.argv.splice(2))
    .usage('Usage: fox <command> [options]')
    .command(RUN_EDITOR, 'open Godot Editor with your main scene')
    .command(RUN_GAME, 'start your game locally')
    .command(EXPORT, 'export a bundle for one of your presets')
    .command(SWITCH, 'switch from a bundle to another (write in override.cfg)')
    .command(UPDATE_PO_FILES, 'calls msgmerge on all .po files in your project -- experimental setup for avindi')
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
      Icons, splashscreens and screenshots commands require ImageMagick https://imagemagick.org/index.php`);

  // -----------------------------------------------------------------------------

  try {
    const result = await cli(yargs, params);
    if (result) {
      console.log(`🦊 ${chalk.italic('done.')}`);
    }
  } catch (e) {
    console.log(e);
    console.log(chalk.red.bold('🔴 failed'));
  }
}

execute()
