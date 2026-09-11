// -----------------------------------------------------------------------------

import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import inquirer from 'inquirer';
import shell from 'shelljs';

// -----------------------------------------------------------------------------

import { colors, foxLogger, godotLogger } from '../logger.js';
import resolveGodotPath from '../resolve-godot.js';
import { readSetting } from './baked-bundle.js';
import ini from './ini.js';
import { TARGET_CHOICES } from './publish-config.js';
import { PRESETS_CFG, readPresets, writePresets } from './read-presets.js';
import { DEFAULT_TARGET, findPreset, readCurrentBundle, targetsForEnv } from './resolve-env-preset.js';
import { bakesSecret, ENV_CHOICES, resolveSteamAppId, writeOverride } from './switch.js';
import { readProjectVersion, tagVersion } from './tag.js';
import updatePreset from './update-preset.js';

// -----------------------------------------------------------------------------

const PROJECT_GODOT = 'project.godot';

const ALL = 'all';

// `Web` sits in the same list as the desktop platforms on purpose: an HTML5 build
// is a build like any other — it carries a [bundle], it belongs to an env and to a
// store, and `fox publish` reads it out of the same `export/<env>/<target>/` tree.
// What differs is handled where it actually differs (no Steam app id, no secret,
// no preset field to rewrite), never by keeping the platform outside the flow.
const PLATFORMS = ['Linux', 'Windows Desktop', 'macOS', 'Web'];

const WEB = 'Web';

// Envs exported with `--export-release`: shipped to players, whatever the store.
const RELEASE_ENVS = ['release', 'demo'];
const PLATFORM_LABELS = { Linux: 'Linux-SteamOS', Web: 'Web (HTML5)' };

const BOLD = '\x1b[1m';
const RESET = '\x1b[0m';

// Bright foregrounds, no background: the chip has to stand out against the
// terminal's own theme, not fight it with a filled block.
const ENV_FOREGROUNDS = {
  debug: '\x1b[94m',
  demo: '\x1b[95m',
  staging: '\x1b[93m',
  release: '\x1b[92m',
};

const TARGET_FOREGROUNDS = {
  steam: '\x1b[96m',
  itch: '\x1b[91m',
};

// -----------------------------------------------------------------------------

export const androidExtension = (env) => (env === 'release' ? '.aab' : '.apk');

export const getApplicationName = (coreConfig, bundle) => {
  const { title } = coreConfig;
  const { subtitle } = bundle;
  return subtitle ? `${title}: ${subtitle}` : title;
};

export const getTitle = (coreConfig) => coreConfig.title;
export const getSubtitle = (bundle) => {
  const { subtitle } = bundle;
  return subtitle;
};

// -----------------------------------------------------------------------------

const verifyBuildFolder = () => {
  const buildFolder = path.resolve(process.cwd(), './_build');

  if (!fs.existsSync(buildFolder)) {
    shell.mkdir('-p', buildFolder);
    foxLogger.success('Created _build folder');
  }
};

// -----------------------------------------------------------------------------
// The bake below rewrites versioned files (project.godot, export_presets.cfg) for
// the duration of the export only, then reverts them with `git restore`. That
// revert is destructive by nature, so it is gated on a clean working tree: with
// nothing pending, there is nothing a restore can throw away. Untracked files are
// ignored — `git restore` never touches them.

const PATCHED_FILES = [PROJECT_GODOT, PRESETS_CFG];

const isGitRepo = () => shell.exec('git rev-parse --is-inside-work-tree', { silent: true }).code === 0;

const verifyCleanTree = () => {
  const { stdout } = shell.exec('git status --porcelain --untracked-files=no', { silent: true });
  const pending = stdout.trim();

  if (!pending) {
    return true;
  }

  foxLogger.error('Working tree is not clean — commit or stash before exporting');
  foxLogger.error('fox bakes [bundle] + Steam app_id into project.godot, then restores it');
  pending.split('\n').forEach((line) => {
    foxLogger.log(line);
  });

  return false;
};

const restorePatchedFiles = () => {
  const files = PATCHED_FILES.filter((file) => fs.existsSync(file));
  shell.exec(`git restore -- ${files.join(' ')}`, { silent: true });
  godotLogger.log(`Restored ${files.join(', ')} (build bake reverted)`);
};

// -----------------------------------------------------------------------------
// Exported builds read `bundle/env` from the project.binary baked into the PCK.
// Godot serializes the in-memory ProjectSettings at export, so we keep both the
// editor source (override.cfg) and the PCK source (project.godot [bundle]) in
// sync for the target platform right before invoking the exporter.
//
// `override.cfg` does NOT reach the PCK (Godot ignores it in editor/headless and
// fox does not ship it next to the binary), so the per-env Steam app_id must be
// baked into project.godot too — otherwise GodotSteam's steamInitEx() reads the
// committed `initialization/app_id=0`. Verified by extracting project.binary from
// the demo PCK: it carried app_id=0 despite override.cfg holding 4873710.

// Same reason as the Steam app_id above: the per-env secrets live in
// `secret.<env>.cfg` (gitignored) and `fox switch` only merges them into
// override.cfg, which never reaches the PCK. An exported build therefore shipped
// the committed empty `custom/leaderboard-secret` — the game queued every score
// and never POSTed one ("no secret configured, holding N submission(s)"), while
// its public GET reads kept working, so the board looked alive with the player
// missing from it. They are baked here and reverted by restorePatchedFiles().
//
// ⛔ Whether a WEB build carries its key is decided by `bakesSecret` (switch.js)
// and by nothing here: the pck of an HTML5 build is downloaded by every visitor
// and readable with a text editor, so a key baked there is PUBLISHED. That is
// acceptable for a demo key — registered on its own row server side, revocable
// alone, and the only way a web player can enter the board at all — and never
// for the release key.
//
// ⛔ When the key IS refused, the refusal must ERASE, never merely abstain.
// `project.godot` is patched once per platform and restored only after the whole
// loop, so in an `all` run the desktop pass has already baked the key by the time
// the web pass arrives: returning early there ships it. Measured on the published
// demo, whose HTML5 pck carried the live key with the desktop fingerprint. A web
// export run ALONE looked clean, which is exactly why the harness never caught it.
const patchProjectGodotSecrets = (env, platform) => {
  let secrets;

  try {
    secrets = ini.parse(fs.readFileSync(`./secret.${env}.cfg`, 'utf8'));
  } catch {
    godotLogger.warn(`No secret.${env}.cfg — [custom] secrets stay as committed`);
    return;
  }

  const cleared = !bakesSecret(platform, env);
  let content = fs.readFileSync(PROJECT_GODOT, 'utf8');
  const touched = [];

  Object.keys(secrets).forEach((key) => {
    const line = new RegExp(`^${key}=.*$`, 'm');
    if (!line.test(content)) {
      godotLogger.warn(`project.godot has no [custom] ${key} — secret NOT baked`);
      return;
    }
    const value = cleared ? '' : String(secrets[key]);
    content = content.replace(line, `${key}=${JSON.stringify(value)}`);
    touched.push(key);
  });

  fs.writeFileSync(PROJECT_GODOT, content);

  if (touched.length === 0) {
    return;
  }

  if (cleared) {
    godotLogger.warn(`Web ${env} build: [custom] ${touched.join(', ')} CLEARED (a web pck is public)`);
    return;
  }

  godotLogger.log(`project.godot [custom] -> baked ${touched.join(', ')} from secret.${env}.cfg`);
};

// What the web pck ACTUALLY carries is read back from the bytes, because the two
// doors into it (project.godot, override.cfg) are set far from here and an
// intention proves nothing — the leak of 2026-09-07 was written as an exemption
// that abstained instead of erasing, and shipped the desktop key.
//
// The check is symmetric, and that is the point: a web `release` must carry NO
// secret, a web demo must carry EXACTLY the key of its own `secret.<env>.cfg`.
// The second half is the negative control the first half lacks — a guard that
// can only ever pass proves nothing, and comparing the VALUE (not its mere
// presence) is what catches the real accident: the key of another env baked by
// the desktop pass of an `all` run and left behind.
export const verifyWebSecrets = (env, exportPath) => {
  let secrets;

  try {
    secrets = ini.parse(fs.readFileSync(`./secret.${env}.cfg`, 'utf8'));
  } catch {
    return true;
  }

  const pck = exportPath.replace(/\.[^.]+$/, '.pck');

  if (!fs.existsSync(pck)) {
    godotLogger.warn(`Web build: no ${path.basename(pck)} to check for secrets`);
    return true;
  }

  const buffer = fs.readFileSync(pck);
  const expected = bakesSecret(WEB, env);

  const wrong = Object.keys(secrets).filter((key) => {
    const carried = readSetting(buffer, `custom/${key}`);

    return expected ? carried !== String(secrets[key]) : typeof carried === 'string' && carried.length > 0;
  });

  const name = path.basename(pck);

  if (wrong.length === 0) {
    godotLogger.success(
      expected
        ? `Web build: ${name} carries the ${env} [custom] ${Object.keys(secrets).join(', ')}`
        : `Web build: ${name} carries no [custom] secret`,
    );
    return true;
  }

  if (expected) {
    godotLogger.error(`Web build MISSES the ${env} [custom] ${wrong.join(', ')} in ${name}`);
    godotLogger.error(`Refusing this build: it could read the board but never post to it`);
    return false;
  }

  godotLogger.error(`Web build LEAKS [custom] ${wrong.join(', ')} into ${name}`);
  godotLogger.error('Refusing this build: a web pck is downloaded by every visitor');
  return false;
};

const patchProjectGodotBundle = ({ platform, env, target, steamAppId }) => {
  let content = fs.readFileSync(PROJECT_GODOT, 'utf8');

  content = content.replace(/^platform=".*"$/m, `platform="${platform}"`);
  content = content.replace(/^env=".*"$/m, `env="${env}"`);

  // A project that predates the target axis has no `target=` line to patch: adding
  // one here would land outside [bundle], so it is left to the project to declare.
  if (/^target=".*"$/m.test(content)) {
    content = content.replace(/^target=".*"$/m, `target="${target}"`);
  }

  if (steamAppId) {
    content = content.replace(/^initialization\/app_id=.*$/m, `initialization/app_id=${steamAppId}`);
  }

  fs.writeFileSync(PROJECT_GODOT, content);

  const steamLog = steamAppId ? ` [steam] app_id=${steamAppId}` : ' (no Steam app_id)';
  godotLogger.log(`project.godot [bundle] -> platform="${platform}" env="${env}" target="${target}"${steamLog}`);
};

// -----------------------------------------------------------------------------

const unzipIPA = (bundleName) => {
  foxLogger.log(`Unzipping ${bundleName}.app...`);

  const absolutePath = `${path.resolve(process.cwd())}/_build/iOS`;
  shell.exec(`tar -xf ${absolutePath}/${bundleName}.ipa -C _build/iOS`);
  shell.rm('-rf', `${absolutePath}/${bundleName}.app`);
  shell.exec(`mv ${absolutePath}/Payload/${bundleName}.app ${absolutePath}/${bundleName}.app`);
  shell.rm('-rf', `${absolutePath}/Payload`);

  foxLogger.success(`_build/iOS/${bundleName}.app is ready for your device`);
  foxLogger.log(`xcrun devicectl device install app _build/iOS/${bundleName}.app --device XXX`);
};

// -----------------------------------------------------------------------------
// The generated assets are gitignored: on a fresh clone, or after a bundle was
// added without regenerating, Godot exports happily with a missing icon and the
// store rejects the build hours later. Naming the file and the command that
// makes it turns that into a five-second fix, before a single byte is written.

const GENERATED_RES_PREFIX = 'res://assets/generated/';

const generateCommandFor = (resPath) => {
  // `boot-splash.png` sits at the root of the generated folder and is spelled
  // with a dash, so it has to be matched before the storyboard images: a
  // `/splash` test alone sends it to the command that never creates it.
  if (resPath.includes('boot-splash')) {
    return 'fox generate:boot-splash';
  }

  if (resPath.includes('/splash')) {
    return 'fox generate:splashscreens';
  }

  return 'fox generate:icons';
};

export const verifyGeneratedAssets = (preset) => {
  const declared = [
    ...new Set(
      Object.values(preset.options || {}).filter(
        (value) => typeof value === 'string' && value.startsWith(GENERATED_RES_PREFIX),
      ),
    ),
  ];

  const missing = declared.filter(
    (resPath) => !fs.existsSync(path.resolve(process.cwd(), resPath.replace('res://', ''))),
  );

  if (!missing.length) {
    godotLogger.success(`${declared.length} generated asset(s) in place`);
    return true;
  }

  foxLogger.error(`${preset.name} declares ${missing.length} generated asset(s) that do not exist:`);
  missing.forEach((resPath) => {
    foxLogger.error(`  ${resPath}`);
  });

  [...new Set(missing.map(generateCommandFor))].forEach((command) => {
    foxLogger.log(`Run \`${command}\` then export again`);
  });

  // `fox export` is called from scripts and CI: a refused export has to be
  // visible in the exit code, not only in the terminal.
  process.exitCode = 1;

  return false;
};

// -----------------------------------------------------------------------------

const exportOnePreset = async (settings, presets, bundleSettings) => {
  const { core: coreConfig, bundles } = settings;
  const { bundleId, preset, env, newVersion } = bundleSettings;

  foxLogger.step(0, `Ready to bundle ${bundleId} (${newVersion}) for ${preset.name}`);

  const { bundleName } = updatePreset(bundleId, env, coreConfig, preset, bundles[bundleId], Object.keys(bundles));

  writePresets(presets);

  if (!verifyGeneratedAssets(preset)) {
    return false;
  }

  // ---------

  if (preset.export_path) {
    const exportDir = path.dirname(path.resolve(process.cwd(), preset.export_path));
    if (!fs.existsSync(exportDir)) {
      shell.mkdir('-p', exportDir);
      godotLogger.success(`Created ${exportDir}`);
    }
  }

  const exportType = `--export-${RELEASE_ENVS.includes(env) ? 'release' : 'debug'}`;
  godotLogger.log(`Exporting with ${exportType}...`);

  return new Promise((resolve) => {
    const bundler = spawn(coreConfig.godot, [exportType, preset.name, '--headless'], {
      stdio: [process.stdin, process.stdout, process.stderr],
    });

    // A spawn that never starts (bad `core.godot` path, missing binary) emits
    // 'error' and NOT a usable close code. Without this listener Node rethrows it
    // as an uncaught exception in the middle of a baked run, i.e. with the secret
    // still sitting in project.godot: resolving false instead routes it through
    // the caller's restore path like any other failure.
    bundler.on('error', (err) => {
      godotLogger.error(`Could not run Godot at ${coreConfig.godot}: ${err.message}`);
      resolve(false);
    });

    bundler.on('close', (code, signal) => {
      if (code !== 0) {
        // A child KILLED by a signal reports `code === null`, which used to print
        // the useless "exit null". The signal is the whole diagnosis: SIGINT is a
        // Ctrl+C (yours or your terminal's), SIGKILL is the OS reclaiming memory,
        // SIGSEGV is an engine crash. Naming it is the difference between a
        // mystery and a one-line answer.
        const cause = signal ? `killed by ${signal}` : `exit ${code}`;
        godotLogger.error(`Export failed for ${preset.name} (${cause})`);
        if (signal === 'SIGINT') {
          godotLogger.log('That is an interruption, not an export error: rerun it.');
        }
        resolve(false);
        return;
      }

      godotLogger.success('Build complete');

      if (preset.platform === 'iOS') {
        if (env === 'debug' || env === 'staging') {
          unzipIPA(bundleName);
        }
        foxLogger.log(`_build/iOS/${bundleName}.xcodeproj is ready to be used with XCode`);
      }

      if (preset.platform === 'Android') {
        foxLogger.log(`_build/android/${bundleName}${androidExtension(env)} is ready`);
        foxLogger.log(`adb install -r _build/android/${bundleName}${androidExtension(env)}`);
      }

      foxLogger.done(`Exported ${bundleId} (${newVersion}) for ${preset.name} ${env}`);
      resolve(true);
    });
  });
};

// -----------------------------------------------------------------------------
// The env decides which presets are exported, hence which folder gets filled.
// `fox publish` reads that folder and never this run, so an export left on the
// wrong env ships stale bytes under a fresh build number — with a build
// description carrying the CURRENT version, which makes the mismatch invisible
// on Steamworks. Both the banner and the env prompt exist to make the target
// folder impossible to miss before a single byte is written.

const exportRootFor = (presets, env, target) => {
  const preset = PLATFORMS.map((platform) => findPreset(presets, platform, env, target)).find(Boolean);

  if (!preset?.export_path) {
    return null;
  }

  return path.dirname(path.dirname(preset.export_path));
};

// `prod` is what ENV_CHOICES calls the `release` env: the chip must speak the
// prompt's language, not the preset's.
const envLabel = (env) => {
  const choice = ENV_CHOICES.find(({ value }) => value === env);
  return (choice ? choice.name : env).toUpperCase();
};

export const envChip = (env) => {
  const foreground = ENV_FOREGROUNDS[env] || colors.white;
  return `${foreground}${BOLD}${envLabel(env)}${RESET}`;
};

const targetLabel = (target) => {
  const choice = TARGET_CHOICES.find(({ value }) => value === target);
  return (choice ? choice.name : target).toUpperCase();
};

export const targetChip = (target) => {
  const foreground = TARGET_FOREGROUNDS[target] || colors.white;
  return `${foreground}${BOLD}${targetLabel(target)}${RESET}`;
};

// What already sits in a folder is what `fox publish` would ship if this run
// filled a different one. Reading it off disk is the only way to tell a fresh
// export from bytes left there weeks ago — the version in the banner describes
// the build about to be made, never the one already lying in the other envs.
const lastExportAt = (presets, env, target) => {
  const stamps = PLATFORMS.map((platform) => {
    const preset = findPreset(presets, platform, env, target);

    if (!preset?.export_path) {
      return null;
    }

    try {
      return fs.statSync(path.resolve(process.cwd(), preset.export_path)).mtime;
    } catch {
      return null;
    }
  }).filter(Boolean);

  if (!stamps.length) {
    return null;
  }

  return new Date(Math.max(...stamps.map((stamp) => stamp.getTime())));
};

const exportedLabel = (presets, env, target) => {
  const stamp = lastExportAt(presets, env, target);

  if (!stamp) {
    return `${colors.gray}(never exported)${colors.reset}`;
  }

  const local = new Date(stamp.getTime() - stamp.getTimezoneOffset() * 60000);
  return `${colors.gray}(last export ${local.toISOString().slice(0, 16).replace('T', ' ')})${colors.reset}`;
};

// Two lines on purpose: the identity of the build on one, the destination it is
// about to fill on the other, arrowed so it reads as a consequence.
const logBundleBanner = ({ presets, title, bundleId, env, target, version, exportRoot }) => {
  const c = colors.cyan;
  const r = colors.reset;
  const destination = exportRoot ? ` ${colors.gray}-> ${exportRoot}/${r}` : '';

  console.log(`${c}├─${r} ${c}●${r} ${BOLD}${title}${r} ${colors.gray}(${bundleId})${r} ${BOLD}v${version}${r}`);
  console.log(
    `${c}├────>${r}  ${envChip(env)} ${colors.gray}on${r} ${targetChip(target)}${destination} ${exportedLabel(presets, env, target)}`,
  );
};

// -----------------------------------------------------------------------------
// Keeping the current env is the default answer: a switch is always an explicit
// choice, never the consequence of hitting enter through the prompts.

const inquireEnv = async (presets, currentEnv, currentTarget) => {
  const others = ENV_CHOICES.filter(({ value }) => value !== currentEnv && targetsForEnv(presets, value).length > 0);

  if (!others.length) {
    return currentEnv;
  }

  const describe = (env) => {
    const target = targetsForEnv(presets, env).includes(currentTarget) ? currentTarget : targetsForEnv(presets, env)[0];
    return `${exportRootFor(presets, env, target)}/ ${exportedLabel(presets, env, target)}`;
  };

  const { env } = await inquirer.prompt([
    {
      message: 'env',
      name: 'env',
      type: 'select',
      choices: [
        {
          name: `keep ${envChip(currentEnv)} (no switch) -> ${describe(currentEnv)}`,
          value: currentEnv,
        },
        ...others.map(({ value }) => ({
          name: `switch to ${envChip(value)} -> ${describe(value)}`,
          value,
        })),
      ],
    },
  ]);

  return env;
};

// -----------------------------------------------------------------------------
// The target is asked only when the env can actually reach more than one store:
// a game with a single destination should never have to answer for it.

const inquireTarget = async (presets, env, currentTarget) => {
  const available = targetsForEnv(presets, env);

  if (available.length < 2) {
    return available[0] || DEFAULT_TARGET;
  }

  const ordered = [
    ...available.filter((target) => target === currentTarget),
    ...available.filter((target) => target !== currentTarget),
  ];

  const { target } = await inquirer.prompt([
    {
      message: 'target',
      name: 'target',
      type: 'select',
      choices: ordered.map((value) => ({
        name: `${targetChip(value)} -> ${exportRootFor(presets, env, value)}/ ${exportedLabel(presets, env, value)}`,
        value,
      })),
    },
  ]);

  return target;
};

// -----------------------------------------------------------------------------

// Only the platforms this (env, target) pair actually has a preset for are
// offered — and `all` means all of THOSE. Listing the full catalogue would let
// `all` pick a platform with no preset, which the guard below turns into an abort:
// asking for everything a store can build would then build nothing.
const platformsFor = (presets, env, target) =>
  PLATFORMS.filter((platform) => findPreset(presets, platform, env, target));

const inquirePlatforms = async (presets, env, target) => {
  const available = platformsFor(presets, env, target);

  if (available.length < 2) {
    return available;
  }

  const { choice } = await inquirer.prompt([
    {
      message: 'platform',
      name: 'choice',
      type: 'select',
      choices: [
        { name: '✨ all', value: ALL },
        ...available.map((platform) => ({ name: PLATFORM_LABELS[platform] || platform, value: platform })),
      ],
    },
  ]);

  return choice === ALL ? available : [choice];
};

// -----------------------------------------------------------------------------

// `forcedEnv` / `forcedTarget` are how `fox publish` re-exports the build it is
// about to upload: the caller already knows both answers, so asking would only be
// a chance to get one wrong.
// --------- non-interactive mode
//
// Every prompt below has an argument that answers it, so a scripted run never
// stops on one. This is what lets a perf loop export the very build it is about
// to publish and measure, over and over, without a human in the terminal:
//
//   fox export --env demo --target itch --platform web
//
// Only the answers given are forced; a missing one is still asked for, so the
// interactive path is untouched. `all` is accepted for --platform.
export const readExportArgs = (params = []) => {
  const value = (name) => {
    const index = params.indexOf(`--${name}`);
    if (index >= 0 && params[index + 1] && !params[index + 1].startsWith('--')) {
      return params[index + 1];
    }
    const inline = params.find((param) => param.startsWith(`--${name}=`));
    return inline ? inline.slice(name.length + 3) : null;
  };

  return {
    forcedEnv: value('env'),
    forcedTarget: value('target'),
    forcedPlatform: value('platform'),
  };
};

// A platform is named on the command line the way a human says it ("web",
// "windows"), never with the exact casing of the Godot preset ("Web Desktop").
const matchPlatform = (available, asked) => {
  if (!asked) {
    return null;
  }
  if (asked === ALL) {
    return available;
  }
  const wanted = asked.toLowerCase();
  const found = available.filter((platform) => platform.toLowerCase().startsWith(wanted));
  return found.length ? found : [];
};

const exportBundle = async (settings, { forcedEnv, forcedTarget, forcedPlatform } = {}) => {
  const { core: coreConfig, bundles } = settings;
  foxLogger.log('Exporting a bundle...');

  if (!bundles) {
    foxLogger.error('Missing bundles in fox.config.json');
    return;
  }

  // The CLI resolves the Godot binary only for the commands it knows need one,
  // and `fox publish` is not one of them — it becomes one the moment it offers
  // to export. Resolving here keeps that dependency owned by the exporter, so
  // publishing from a machine without Godot still works right up to the offer.
  if (!coreConfig.godot) {
    const godotPath = resolveGodotPath(coreConfig.godot);

    if (!godotPath) {
      return;
    }

    coreConfig.godot = godotPath;
  }

  // ---------

  verifyBuildFolder();

  // --------- versioned files are baked then restored: refuse a dirty tree

  const gitTracked = isGitRepo();

  if (gitTracked && !verifyCleanTree()) {
    return;
  }

  if (!gitTracked) {
    foxLogger.log('Not a git repository — project.godot will keep the baked values');
  }

  // ---------

  let presets = readPresets();
  if (!presets) {
    foxLogger.error('Failed during reading presets');
    return;
  }

  // --------- env comes from the last `fox switch`, and can be switched right here

  const current = readCurrentBundle();
  const currentEnv = current?.env;
  const currentTarget = current?.target || DEFAULT_TARGET;
  const bundleId = current?.id || Object.keys(bundles)[0];

  if (!currentEnv) {
    foxLogger.error('No current env in override.cfg — run `fox switch` first');
    return;
  }

  logBundleBanner({
    presets,
    title: getTitle(coreConfig),
    bundleId,
    env: currentEnv,
    target: currentTarget,
    version: readProjectVersion(),
    exportRoot: exportRootFor(presets, currentEnv, currentTarget),
  });

  const env = forcedEnv || (await inquireEnv(presets, currentEnv, currentTarget));

  if (env !== currentEnv) {
    foxLogger.warn(`switching env: ${currentEnv} -> ${env} (override.cfg is rewritten)`);
  }

  const target = forcedTarget || (await inquireTarget(presets, env, currentTarget));

  if (target !== currentTarget) {
    foxLogger.warn(`switching target: ${currentTarget} -> ${target} (override.cfg is rewritten)`);
  }

  // ---------

  const available = platformsFor(presets, env, target);
  const platforms = forcedPlatform
    ? matchPlatform(available, forcedPlatform)
    : await inquirePlatforms(presets, env, target);

  if (forcedPlatform && !platforms.length) {
    foxLogger.error(`--platform ${forcedPlatform} matches none of: ${available.join(', ')}`);
    return;
  }

  // --------- every target must resolve to a preset before any versioning

  if (!platforms.length) {
    foxLogger.error(`No preset with env:${env},target:${target} for any known platform`);
    foxLogger.error('Aborting: add the matching preset in export_presets.cfg');
    return;
  }

  for (const platform of platforms) {
    if (!findPreset(presets, platform, env, target)) {
      foxLogger.error(`No preset with env:${env},target:${target} for platform "${platform}"`);
      foxLogger.error('Aborting: add the matching preset in export_presets.cfg');
      return;
    }
  }

  // --------- version resolved once: a single tag even when building `all`

  let newVersion;

  if (env === 'release') {
    newVersion = await tagVersion();
    if (!newVersion) {
      foxLogger.error('Failed during versioning');
      return;
    }
    presets = readPresets();
  } else {
    newVersion = readProjectVersion();
    foxLogger.log(`env=${env} — skipping version bump (using ${newVersion})`);
  }

  // ---------

  try {
    for (const platform of platforms) {
      const preset = findPreset(presets, platform, env, target);

      foxLogger.log(`--- ${platform} (${env} on ${target}) -> ${preset.export_path} ---`);

      writeOverride(settings, { bundleId, platform, env, target });
      patchProjectGodotBundle({
        platform,
        env,
        target,
        steamAppId: resolveSteamAppId(settings, env, target),
      });
      patchProjectGodotSecrets(env, platform);

      const ok = await exportOnePreset(settings, presets, { bundleId, preset, env, newVersion });
      if (!ok) {
        foxLogger.error(`Aborting run: ${preset.name} failed`);
        return;
      }

      if (platform === WEB && !verifyWebSecrets(env, preset.export_path)) {
        foxLogger.error(`Aborting run: ${preset.name} does not carry the secrets it should`);
        return;
      }
    }
  } finally {
    if (gitTracked) {
      restorePatchedFiles();
    }
  }

  if (env !== currentEnv || target !== currentTarget) {
    foxLogger.warn(
      `override.cfg now holds env=${env} target=${target} — \`fox switch\` to go back to ${currentEnv}/${currentTarget}`,
    );
  }

  foxLogger.done(
    `Exported ${platforms.length} platform(s) (${newVersion}) for "${env}" on "${target}" -> ${exportRootFor(presets, env, target)}/`,
  );

  return true;
};

// -----------------------------------------------------------------------------

export default exportBundle;
