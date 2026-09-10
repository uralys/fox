// -----------------------------------------------------------------------------

import { presetLogger } from '../logger.js';
import { androidExtension, getApplicationName } from './export.js';
import { toVersionNumber } from './versioning.js';

// -----------------------------------------------------------------------------

const MAC_OSX = 'Mac OSX';
const MACOS = 'macOS';
const IOS = 'iOS';
const ANDROID = 'Android';
const WEB = 'Web';
const WINDOWS = 'Windows Desktop';
const LINUX = 'Linux';

// The generated assets live under `assets/generated/<bundleId>/<platform folder>/`.
// A preset only ever needs its own bundle and its own platform folder: everything
// else is dead weight in the build, which is what issue #14 was about.
const GENERATED_ROOT = 'assets/generated';
const GENERATED_PREFIX = `res://${GENERATED_ROOT}/`;

const IOS_FOLDER = 'ios';
const ANDROID_FOLDER = 'android';
const DESKTOP_FOLDER = 'desktop';
const WEB_FOLDER = 'web';

const PLATFORM_FOLDERS = [IOS_FOLDER, ANDROID_FOLDER, DESKTOP_FOLDER, WEB_FOLDER];

const FOLDER_BY_PLATFORM = {
  [IOS]: IOS_FOLDER,
  [ANDROID]: ANDROID_FOLDER,
  [WEB]: WEB_FOLDER,
  [MAC_OSX]: DESKTOP_FOLDER,
  [MACOS]: DESKTOP_FOLDER,
  [WINDOWS]: DESKTOP_FOLDER,
  [LINUX]: DESKTOP_FOLDER,
};

// macOS only reads a real .icns, Windows only a real .ico; Linux takes the png.
const DESKTOP_ICON_FILE = {
  [MAC_OSX]: 'icon.icns',
  [MACOS]: 'icon.icns',
  [WINDOWS]: 'icon.ico',
  [LINUX]: 'icon.png',
};

// Windows stamps both into the exe metadata; Godot refuses anything but x.y.z[.w].
const DESKTOP_VERSION_KEYS = ['application/file_version', 'application/product_version'];

const LEGACY_LAUNCH_SCREEN_PREFIXES = ['landscape_launch_screens/', 'portrait_launch_screens/'];

// -----------------------------------------------------------------------------

const updateOptions = (preset, key, value) => {
  preset.options[key] = value;
  presetLogger.log(`${key} = ${value}`);
};

const updateMain = (preset, key, value) => {
  preset[key] = value;
  presetLogger.log(`${key} = ${value}`);
};

// -----------------------------------------------------------------------------

const isGeneratedPath = (value) => typeof value === 'string' && value.startsWith(GENERATED_PREFIX);

const generatedPath = (bundleId, folder, file) => `${GENERATED_PREFIX}${bundleId}/${folder}/${file}`;

// -----------------------------------------------------------------------------
// Godot has no "exclude everything but this" filter, so the foreign folders are
// listed one by one: the other platforms of this bundle, then the other bundles
// whole. The game's own filters are kept as they are — only the tokens under
// `assets/generated/` belong to fox, which is what makes a re-export idempotent.

const updateGeneratedFilters = (preset, bundleId, bundleIds) => {
  const folder = FOLDER_BY_PLATFORM[preset.platform];

  if (!folder) {
    presetLogger.warn(`Platform ${preset.platform} has no generated folder, exclude_filter kept`);
    return;
  }

  const gameFilters = (preset.exclude_filter || '')
    .split(',')
    .map((token) => token.trim())
    .filter((token) => token.length > 0 && !token.startsWith(`${GENERATED_ROOT}/`));

  const foreign = [
    ...PLATFORM_FOLDERS.filter((name) => name !== folder).map((name) => `${GENERATED_ROOT}/${bundleId}/${name}/*`),
    ...bundleIds
      .filter((id) => id !== bundleId)
      .sort()
      .map((id) => `${GENERATED_ROOT}/${id}/*`),
  ];

  updateMain(preset, 'exclude_filter', [...gameFilters, ...foreign].join(','));
};

// -----------------------------------------------------------------------------
// Only the slots already pointing inside `assets/generated/` are rewritten: a
// game shipping a handmade icon from anywhere else keeps it.

const updateIOSIcons = (preset, bundleId) => {
  Object.keys(preset.options)
    .filter((key) => key.startsWith('icons/') && isGeneratedPath(preset.options[key]))
    .forEach((key) => {
      const match = key.match(/_(\d+)x(\d+)$/);

      if (!match || match[1] !== match[2]) {
        return;
      }

      // generate:icons names them `icon-<size>x<size>.png`: any other spelling
      // here makes the export preflight refuse every iOS build.
      const size = match[1];

      updateOptions(preset, key, generatedPath(bundleId, IOS_FOLDER, `icon-${size}x${size}.png`));
    });
};

const ANDROID_ICON_FILES = {
  'launcher_icons/main_192x192': 'icon-192x192.png',
  'launcher_icons/adaptive_foreground_432x432': 'adaptive-foreground.png',
  'launcher_icons/adaptive_background_432x432': 'adaptive-background.png',
};

const updateAndroidIcons = (preset, bundleId) => {
  Object.keys(ANDROID_ICON_FILES)
    .filter((key) => isGeneratedPath(preset.options[key]))
    .forEach((key) => {
      updateOptions(preset, key, generatedPath(bundleId, ANDROID_FOLDER, ANDROID_ICON_FILES[key]));
    });
};

// generate:icons writes the PWA set as `pwa-<size>x<size>.png`. A project whose
// web preset points these slots inside `assets/generated/` would otherwise keep
// a path nothing produces any more, and the export preflight would refuse the
// build with a command that never fixes it.
const WEB_ICON_FILES = {
  'progressive_web_app/icon_144x144': 'pwa-144x144.png',
  'progressive_web_app/icon_180x180': 'pwa-180x180.png',
  'progressive_web_app/icon_512x512': 'pwa-512x512.png',
};

const updateWebIcons = (preset, bundleId) => {
  Object.keys(WEB_ICON_FILES)
    .filter((key) => isGeneratedPath(preset.options[key]))
    .forEach((key) => {
      updateOptions(preset, key, generatedPath(bundleId, WEB_FOLDER, WEB_ICON_FILES[key]));
    });
};

const updateDesktopIcons = (preset, bundleId) => {
  const iconFile = DESKTOP_ICON_FILE[preset.platform] || 'icon.png';

  if (isGeneratedPath(preset.options['application/icon'])) {
    updateOptions(preset, 'application/icon', generatedPath(bundleId, DESKTOP_FOLDER, iconFile));
  }

  if (isGeneratedPath(preset.options['application/console_wrapper_icon'])) {
    updateOptions(preset, 'application/console_wrapper_icon', generatedPath(bundleId, DESKTOP_FOLDER, 'icon.ico'));
  }
};

// -----------------------------------------------------------------------------
// The 11 legacy launch screens are replaced by the storyboard pair. Migrating
// only presets whose launch screens were generated leaves a game driving its own
// storyboard untouched, and re-running finds `custom_image@2x` already generated:
// same result, no flip-flop.

const updateIOSStoryboard = (preset, bundleId) => {
  const legacyKeys = Object.keys(preset.options).filter((key) =>
    LEGACY_LAUNCH_SCREEN_PREFIXES.some((prefix) => key.startsWith(prefix)),
  );

  const wasGenerated =
    legacyKeys.some((key) => isGeneratedPath(preset.options[key])) ||
    isGeneratedPath(preset.options['storyboard/custom_image@2x']);

  if (!wasGenerated) {
    return;
  }

  updateOptions(preset, 'storyboard/use_launch_screen_storyboard', true);
  updateOptions(preset, 'storyboard/custom_image@2x', generatedPath(bundleId, IOS_FOLDER, 'splash@2x.png'));
  updateOptions(preset, 'storyboard/custom_image@3x', generatedPath(bundleId, IOS_FOLDER, 'splash@3x.png'));

  legacyKeys
    .filter((key) => preset.options[key] !== '')
    .forEach((key) => {
      updateOptions(preset, key, '');
    });
};

// -----------------------------------------------------------------------------

const updateAndroidPreset = (env, preset, bundle, bundleId, applicationName, bundleName) => {
  updateMain(preset, 'export_path', `_build/android/${bundleName}${androidExtension(env)}`);

  updateOptions(preset, 'package/name', applicationName);

  const packageUIDKey = 'package/unique_name';
  const packageUID = bundle[ANDROID]?.[packageUIDKey] || bundle.uid;
  updateOptions(preset, packageUIDKey, packageUID);

  if (env === 'release' && bundle[ANDROID]['keystore/release_user']) {
    updateOptions(preset, 'keystore/release_user', bundle[ANDROID]['keystore/release_user']);
  }

  updateAndroidIcons(preset, bundleId);
};

// -----------------------------------------------------------------------------

const updateIOSPreset = (_env, preset, bundle, bundleId, applicationName, bundleName) => {
  updateMain(preset, 'export_path', `_build/iOS/${bundleName}.ipa`);

  updateOptions(preset, 'application/name', applicationName);

  const packageUID = bundle[IOS]?.['application/bundle_identifier'] || bundle.uid;
  updateOptions(preset, 'application/bundle_identifier', packageUID);

  updateIOSIcons(preset, bundleId);
  updateIOSStoryboard(preset, bundleId);
};

// -----------------------------------------------------------------------------

const updateMacOSXPreset = (_env, preset, bundle, bundleId, applicationName, bundleName) => {
  updateMain(preset, 'export_path', `_build/macOS/${bundleName}`);

  updateOptions(preset, 'application/name', applicationName);

  const packageUID = bundle[IOS]?.['application/bundle_identifier'] || bundle.uid;
  updateOptions(preset, 'application/bundle_identifier', packageUID);

  updateDesktopIcons(preset, bundleId);
};

// -----------------------------------------------------------------------------
// The Godot 4 desktop presets (macOS, Windows Desktop, Linux) ship through the
// `export/<env>/<target>/` tree, which is the only place `fox publish` looks. So
// their `export_path` and their bundle identifier belong to the project: a game
// declares one folder per env and per store, and one identifier per build. Fox
// fills what it owns and nothing else — the display name Godot actually reads on
// that platform, and the generated icons.
//
// ⛔ Never rewrite `export_path` here. Sending a macOS build to `_build/macOS/`
// leaves `export/<env>/<target>/macos/` holding the bytes of the previous run,
// which publish then uploads under a fresh build number: stale content shipped,
// invisible on the store side because the description carries the new version.

const DESKTOP_NAME_KEY = {
  [MACOS]: 'application/name',
  [WINDOWS]: 'application/product_name',
  [LINUX]: 'application/product_name',
};

const updateDesktopPreset = (preset, bundleId, applicationName) => {
  const nameKey = DESKTOP_NAME_KEY[preset.platform];

  if (nameKey && nameKey in preset.options) {
    updateOptions(preset, nameKey, applicationName);
  }

  // Windows and Linux name the executable through `application/product_name`;
  // `application/name` is a macOS key Godot never reads there, and fox is what
  // used to write it. Dropping it keeps export_presets.cfg honest.
  if (preset.platform !== MACOS && 'application/name' in preset.options) {
    delete preset.options['application/name'];
    presetLogger.log('application/name removed (not read on this platform)');
  }

  updateDesktopIcons(preset, bundleId);
};

// -----------------------------------------------------------------------------

export const updateVersionInPreset = (preset, newVersion) => {
  const { platform, name } = preset;
  presetLogger.log(`Updating version for ${name}`);

  switch (platform) {
    case ANDROID:
      updateOptions(preset, 'version/code', toVersionNumber(newVersion));
      updateOptions(preset, 'version/name', newVersion);
      break;
    case IOS:
    case MAC_OSX:
    case MACOS:
      updateOptions(preset, 'application/short_version', newVersion);
      updateOptions(preset, 'application/version', newVersion);
      break;
    // The Windows exe carries its version in its own metadata, read by the OS
    // and by Steam's crash reports. Left alone it kept the number of whichever
    // release first filled it, months behind the tag being built.
    case WINDOWS:
    case LINUX:
      DESKTOP_VERSION_KEYS.filter((key) => key in preset.options).forEach((key) => {
        updateOptions(preset, key, newVersion);
      });
      break;
  }
};

// -----------------------------------------------------------------------------

const updatePreset = (bundleId, env, coreConfig, preset, bundle, bundleIds = [bundleId]) => {
  const { platform } = preset;
  presetLogger.log(`Updating ${platform} preset`);

  const _applicationName = getApplicationName(coreConfig, bundle);

  const envSuffix = env === 'release' ? '' : env === 'demo' ? ' Demo' : `(${env})`;
  const applicationName = `${_applicationName}${envSuffix}`;
  const bundleName = `${bundleId}${env === 'release' ? '' : `-${env}`}`;

  updateGeneratedFilters(preset, bundleId, bundleIds);

  switch (platform) {
    case ANDROID:
      updateAndroidPreset(env, preset, bundle, bundleId, applicationName, bundleName);
      break;
    case IOS:
      updateIOSPreset(env, preset, bundle, bundleId, applicationName, bundleName);
      break;
    case MAC_OSX:
      updateMacOSXPreset(env, preset, bundle, bundleId, applicationName, bundleName);
      break;
    case MACOS:
    case WINDOWS:
    case LINUX:
      updateDesktopPreset(preset, bundleId, applicationName);
      break;
    case WEB:
      // A web export has no application name and no bundle identifier: the page
      // is named by its <title>, which the project owns. Its export_path is left
      // exactly as the preset declares it: the folder under export/<env>/<target>/
      // is where `fox publish` will come looking. Only the PWA icons, when the
      // project pointed them at the generated folder, follow the convention.
      presetLogger.log('Web preset kept as declared (no name, no uid)');
      updateWebIcons(preset, bundleId);
      break;
    default:
      presetLogger.warn(`Platform ${platform} has no preset specificity, icons only`);
      updateDesktopIcons(preset, bundleId);
  }

  presetLogger.success('Preset updated');

  return {
    applicationName,
    bundleName,
  };
};

// -----------------------------------------------------------------------------

export default updatePreset;
