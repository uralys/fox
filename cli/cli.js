#!/usr/bin/env -S node --no-warnings

// -----------------------------------------------------------------------------

import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import shell from 'shelljs';
import yargsFactory from 'yargs';

import pkg from '../package.json' with { type: 'json' };
import { foxLogger, godotLogger } from './logger.js';

// -----------------------------------------------------------------------------

import exportBundle, { readExportArgs } from './bundler/export.js';
import exportWeb from './bundler/export-web.js';
import publish from './bundler/publish.js';
import switchBundle from './bundler/switch.js';
import { SEMVER_LEVELS, tagVersion } from './bundler/tag.js';
import generateBootSplash from './generate-boot-splash.js';
import generateIcons from './generate-icons.js';
import generateScreenshots from './generate-screenshots.js';
import generateSplashscreens from './generate-splashscreens.js';
import generateSteamScreenshots from './generate-steam-screenshots.js';
import { printHelp } from './help.js';
import importAssets from './import-assets.js';
import { notifyLatestRelease } from './latest-release.js';
import link from './link.js';
import ls from './ls/index.js';
import { ADDON_MOUNT, describeMountLabel, readMountedVersion, resolveFoxPath } from './resolve-fox-mount.js';
import resolveGodotPath from './resolve-godot.js';
import runGame from './run-game.js';
import upgrade from './upgrade.js';

// -----------------------------------------------------------------------------

const TAG = 'tag';
const UPGRADE = 'upgrade';
// `update` says the same thing to fingers that learned it elsewhere.
const UPGRADE_ALIAS = 'update';
const LINK = 'link';
const EXPORT = 'export';
const EXPORT_WEB = 'export:web';
const PUBLISH = 'publish';
const SWITCH = 'switch';
const LS = 'ls';
const LS_STEAM = 'ls:steam';
const LS_ITCH = 'ls:itch';

const GENERATE_ICONS = 'generate:icons';
const GENERATE_SPLASHSCREENS = 'generate:splashscreens';
const GENERATE_BOOT_SPLASH = 'generate:boot-splash';
const GENERATE_SCREENSHOTS = 'generate:screenshots';
const GENERATE_STEAM_SCREENSHOTS = 'generate:steam-screenshots';
const UPDATE_PO_FILES = 'update-po-files';

const RUN_EDITOR = 'run:editor';
const RUN_GAME = 'run:game';
const IMPORT = 'import';

// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// THE command table: what fox can do, in the order a reader discovers it. yargs
// registers itself from this list and `fox --help` renders it (help.js), so a
// new command is declared once, here.

const COMMAND_GROUPS = [
  {
    title: 'play',
    commands: [
      [RUN_EDITOR, 'open Godot Editor with your main scene'],
      [RUN_GAME, 'start your game locally'],
      [IMPORT, 'import assets headless, as the editor does when opening the project (fox import [--force])'],
    ],
  },
  {
    title: 'ship',
    commands: [
      [TAG, 'bump version in project.godot and create git tag (fox tag [patch|minor|major])'],
      [SWITCH, 'switch from a bundle to another (write in override.cfg)'],
      [EXPORT, 'export a bundle for one of your presets (--env / --target / --platform to skip the prompts)'],
      [
        EXPORT_WEB,
        'scriptable HTML5 export into _build/web, NOT shippable (no bundle bake): use `fox export` to ship a web build',
      ],
      [PUBLISH, 'upload exported builds to a store (fox publish [store] [env] [branch], --yes to skip the confirm)'],
      [LS, 'list local exports and confront them with every store: Steam Deck and itch.io'],
      [LS_STEAM, 'list local Steam exports and the builds installed on the Steam Deck, and compare them'],
      [LS_ITCH, 'list local itch exports and the builds live on the itch.io page, and compare them'],
    ],
  },
  {
    title: 'fox itself',
    commands: [
      [UPGRADE, `pin ${ADDON_MOUNT} to a released version and reimport (fox upgrade [version] [--no-import])`],
      [
        LINK,
        `mount your local fox checkout in ${ADDON_MOUNT} to follow it live, and reimport (fox link [path-to-fox])`,
      ],
    ],
  },
  {
    title: 'generate',
    commands: [
      [
        GENERATE_ICONS,
        'generate icons from a base 1200x1200 image, per bundle and per platform, into assets/generated/<bundleId>/{ios,android,desktop,web}',
      ],
      [
        GENERATE_SPLASHSCREENS,
        'generate the iOS launch storyboard images (@2x, @3x) into assets/generated/<bundleId>/ios',
      ],
      [
        GENERATE_BOOT_SPLASH,
        'generate the Godot boot splash frame (assets/generated/boot-splash.png), sized from addons/fox/components/splash/splash-screen.gd',
      ],
      [GENERATE_SCREENSHOTS, 'resize all images in a folder to 2560x1600, to match store requirements'],
      [GENERATE_STEAM_SCREENSHOTS, 'resize all images from <source-folder> to 1920x1080 for Steam (flat output)'],
      [UPDATE_PO_FILES, 'calls msgmerge on all .po files in your project -- experimental setup for avindi'],
    ],
  },
];

// `upgrade` answers to `update` too, and that alias stays out of the help: it
// is the same command, not a second one to read.
const commands = [UPGRADE_ALIAS, ...COMMAND_GROUPS.flatMap(({ commands: group }) => group.map(([name]) => name))];

const DOCS = 'https://github.com/uralys/fox';

const showHelp = () => printHelp(COMMAND_GROUPS, { version: pkg.version, docs: DOCS });

const HELP_FLAGS = ['-h', '--help'];

// -----------------------------------------------------------------------------

// Relative to the Fox mount, resolved at runtime: `addons/fox` on a migrated
// project, `fox` on a project still on the legacy mount.
const DEFAULT_CONFIG_FILE = 'default.config.json';
const CONFIG_FILE = 'fox.config.json';

// -----------------------------------------------------------------------------

const getSettings = async (command, defaultConfig) => {
  let config;
  const configPath = path.resolve(process.cwd(), `./${CONFIG_FILE}`);

  try {
    foxLogger.log(`Reading ${CONFIG_FILE}`);
    config = (await import(pathToFileURL(configPath), { with: { type: 'json' } })).default;

    // Only the command block falls back: swapping the whole config in would
    // also swap `bundles`, and every generated asset would land under the
    // example bundle of the default config instead of the project's own.
    if (!config[command] && defaultConfig[command]) {
      foxLogger.warn(`Using default config for command "${command}"`);
    }
  } catch {
    foxLogger.warn(`Could not find ${CONFIG_FILE}, using default config for "${command}"`);
    config = defaultConfig;
    return;
  }

  return {
    config: { ...defaultConfig[command], ...config[command] },
    core: { ...defaultConfig.core, ...config.core },
    bundles: config.bundles,
    publish: { ...defaultConfig.publish, ...config.publish },
  };
};

// -----------------------------------------------------------------------------

const verifyConfig = (config, defaultConfig) => {
  const requirements = Object.keys(defaultConfig);

  requirements.forEach((requirement) => {
    const value = config[requirement];
    if (!value) {
      foxLogger.error(`${requirement} not provided in your config`);
      throw new Error(`${requirement} not provided in your config`);
    }
  });

  if (config.output) {
    const projectPath = path.resolve(process.cwd(), './');
    const output = `${projectPath}/${config.output}`;

    // An `output` naming a file (the boot splash frame) only needs its parent
    // directory: creating `boot-splash.png` as a folder would break the render.
    const directory = path.extname(output) ? path.dirname(output) : output;

    foxLogger.log(`Verifying output path`);
    foxLogger.data({ output: directory });

    if (!fs.existsSync(directory)) {
      shell.mkdir('-p', directory);
      foxLogger.success('Created output directory');
    }
  }
};

// -----------------------------------------------------------------------------

const cli = async (yargs, params) => {
  const command = yargs.argv._[0];

  if (!commands.includes(command)) {
    showHelp();
    return;
  }

  // Never let `-h`/`--help` on a subcommand fall through as a positional
  // argument: `fox publish --help` would otherwise read `--help` as a branch
  // name and trigger a real publish.
  if (params.some((param) => HELP_FLAGS.includes(param))) {
    showHelp();
    return;
  }

  // --------

  if (command === TAG) {
    const levelArg = SEMVER_LEVELS.includes(params[0]) ? params[0] : null;
    await tagVersion(levelArg);
    return true;
  }

  // --------

  // These two change the mount itself, so they run before the default config
  // is read: that file lives inside the very folder they are about to replace,
  // and a game being mounted for the first time has none yet.
  if (command === UPGRADE || command === UPGRADE_ALIAS) {
    return await upgrade(params);
  }

  if (command === LINK) {
    return await link(params);
  }

  // --------

  // The mount is its own line, above the tree: it belongs to the project, not
  // to the command, and putting it on the `●` line printed the version twice
  // when the CLI and the addon happened to be on the same one.
  const mountLabel = describeMountLabel();

  if (mountLabel) {
    console.log(`🦊 ${mountLabel}`);
  }

  foxLogger.log(command);

  // The executable is global, one per machine, while a mount is per project:
  // `fox upgrade` and `fox link` both repoint it, so the last one run owns it.
  // Saying nothing when they agree keeps the header to one number; saying it
  // when they do not is the only warning a mismatched pair ever gets.
  const mountedVersion = readMountedVersion();

  if (mountedVersion && mountedVersion !== pkg.version) {
    foxLogger.warn(`this CLI is v${pkg.version}: run \`fox upgrade\` to match the addon`);
  }

  const defaultConfigPath = path.resolve(process.cwd(), resolveFoxPath(DEFAULT_CONFIG_FILE));

  let defaultConfig;

  try {
    defaultConfig = (await import(pathToFileURL(defaultConfigPath), { with: { type: 'json' } })).default;
  } catch {
    foxLogger.error(`${process.cwd()} is not a project using Fox: no ${ADDON_MOUNT}/${DEFAULT_CONFIG_FILE}`);
    return;
  }

  const settings = await getSettings(command, defaultConfig);

  if (!settings) {
    return;
  }

  const { core, config, bundles } = settings;

  // -------- resolve Godot path

  const godotCommands = [RUN_EDITOR, RUN_GAME, IMPORT, EXPORT, EXPORT_WEB];

  if (godotCommands.includes(command)) {
    const godotPath = resolveGodotPath(core.godot);
    if (!godotPath) return;
    core.godot = godotPath;
  }

  // -------- Godot commands

  switch (command) {
    case RUN_EDITOR: {
      const { resolution, position } = config;
      godotLogger.log('Opening editor');
      godotLogger.data({ resolution, position });

      const editorProcess = spawn(
        core.godot,
        ['-e', '--windowed', '--resolution', resolution, '--position', position],
        { stdio: [process.stdin, process.stdout, process.stderr] },
      );

      editorProcess.on('close', () => {
        foxLogger.done('bye!');
      });

      return;
    }
    case RUN_GAME: {
      runGame(core.godot, params, config);
      return;
    }
    case IMPORT: {
      return await importAssets(core.godot, params);
    }
    case EXPORT: {
      await exportBundle(settings, readExportArgs(params));
      return;
    }
    case EXPORT_WEB: {
      await exportWeb(settings);
      return;
    }
    case PUBLISH: {
      await publish(settings, params);
      return;
    }
    case SWITCH: {
      await switchBundle(settings);
      return;
    }
    case LS: {
      return await ls(settings);
    }
    case LS_STEAM: {
      return await ls(settings, 'steam');
    }
    case LS_ITCH: {
      return await ls(settings, 'itch');
    }
  }

  // -------- IO commands

  verifyConfig(config, defaultConfig[command]);

  switch (command) {
    case GENERATE_ICONS: {
      return generateIcons(config, bundles);
    }
    case GENERATE_SPLASHSCREENS: {
      return generateSplashscreens(config, bundles);
    }
    case GENERATE_BOOT_SPLASH: {
      return generateBootSplash(config);
    }
    case UPDATE_PO_FILES: {
      const { poFiles, potTemplate } = config;
      foxLogger.log('Using msgmerge on .po files');
      shell.exec(
        `for file in ${poFiles}; do echo \${file} ; msgmerge --backup=off --update \${file} ${potTemplate}; done`,
      );
      break;
    }
    case GENERATE_SCREENSHOTS: {
      return generateScreenshots(config);
    }
    case GENERATE_STEAM_SCREENSHOTS: {
      return generateSteamScreenshots(config, params);
    }
    default: {
      foxLogger.error(`${command} not handled`);
    }
  }

  return true;
};

// -----------------------------------------------------------------------------

// The last thing every command prints, success or failure: the mounted addon is
// compared with the latest release, and a newer one gets a line. Asking GitHub
// is rate limited to once every six hours for the whole machine, so this costs
// nothing on the commands in between (see latest-release.js).
//
// The two commands that move the mount are left out: `upgrade` has just pinned
// what it was told to, and `link` deliberately leaves the project off any
// release.
const MOUNT_COMMANDS = [UPGRADE, UPGRADE_ALIAS, LINK];

const notifyNewRelease = async (command) => {
  if (!commands.includes(command) || MOUNT_COMMANDS.includes(command)) {
    return;
  }

  await notifyLatestRelease();
};

// -----------------------------------------------------------------------------

const execute = async () => {
  const params = process.argv.slice(3);

  // Read before yargs is built: the factory below SPLICES `process.argv`, so
  // the command name is gone from it by the time the command has run.
  const command = process.argv[2];

  const yargs = COMMAND_GROUPS.flatMap(({ commands: group }) => group)
    .reduce(
      (parser, [name, description]) => parser.command(name, description),
      yargsFactory(process.argv.splice(2)).scriptName('fox').usage('Usage: fox <command> [options]'),
    )
    // fox prints its own help (help.js): yargs would render the same table
    // without colours, wrapped inside words, under headings translated to the
    // system locale.
    .help(false)
    .version(pkg.version)
    .alias('version', 'v');

  // -----------------------------------------------------------------------------

  try {
    const result = await cli(yargs, params);

    // A command reporting `false` failed: leaving the exit code at 0 would make
    // a broken generation look like a success to any script calling fox.
    if (result === false) {
      process.exitCode = 1;
      return;
    }

    if (result) {
      foxLogger.done('done.');
    }
  } catch (e) {
    foxLogger.error(e.message || String(e));
    process.exitCode = 1;
  }

  await notifyNewRelease(command);
};

execute();
