// -----------------------------------------------------------------------------
// generates icons from a base image, per bundle and per platform
// requires ImageMagick, see docs/install.md
// -----------------------------------------------------------------------------
// based on 🍒 https://github.com/chrisdugne/cherry/blob/master/prepare-icons.sh
// -----------------------------------------------------------------------------
// layout, consumed as is by the export presets:
//
//   assets/generated/<bundleId>/ios/      icon-<size>x<size>.png
//   assets/generated/<bundleId>/android/  icon-192x192.png + adaptive elements
//   assets/generated/<bundleId>/desktop/  icon.png, icon.ico, icon.icns
//   assets/generated/<bundleId>/web/      pwa-<size>x<size>.png
//
// Only the sizes an export preset actually reads are produced: the 20, 29, 32,
// 64, 128, 256 and 512 icons no build ever consumed are gone.
// -----------------------------------------------------------------------------

import fs from 'fs';
import shell from 'shelljs';
import {buildIcns, buildIco} from './icon-formats.js';
import {ensureImageMagick, quote, runMagick} from './imagemagick.js';
import {iconsLogger} from './logger.js';

// -----------------------------------------------------------------------------

// https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/AppIconType.html
const IOS_SIZES = [40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024];

const ANDROID_SIZE = 192;

const WEB_SIZES = [144, 180, 512];

const DESKTOP_SIZE = 512;

const PLATFORMS = ['ios', 'android', 'desktop', 'web'];

// A project without a `bundles` section still gets the target layout, under a
// single folder, so the presets never have to special case it.
const FALLBACK_BUNDLE_ID = 'default';

// -----------------------------------------------------------------------------

// `output` is the root of the generated assets. Projects created before the
// per-platform layout point it at the flat `.../generated/icons` folder: that
// trailing segment is dropped so their config keeps working untouched.
const generatedRoot = (output) => output.replace(/\/+$/, '').replace(/\/icons$/, '');

// -----------------------------------------------------------------------------

const resizeIcon = (source, size, target) =>
  runMagick(
    [
      quote(source),
      '-resize',
      quote(`${size}x${size}`),
      '-unsharp',
      '1x4',
      quote(target)
    ],
    iconsLogger
  );

// -----------------------------------------------------------------------------

const generateBundle = ({bundleId, root, source, desktopSource, adaptive}) => {
  const folders = {};

  for (const platform of PLATFORMS) {
    folders[platform] = `${root}/${bundleId}/${platform}`;
    shell.mkdir('-p', folders[platform]);
  }

  const counters = {ios: 0, android: 0, desktop: 0, web: 0};

  iconsLogger.step(0, `${bundleId}: iOS icons`);

  for (const size of IOS_SIZES) {
    const name = `icon-${size}x${size}.png`;

    if (!resizeIcon(source, size, `${folders.ios}/${name}`)) {
      iconsLogger.error(`Aborting: could not generate ${bundleId}/ios/${name}`);
      return null;
    }

    counters.ios += 1;
    iconsLogger.successCompact(`ios/${name}`);
  }

  iconsLogger.step(1, `${bundleId}: Android icons`);

  const androidName = `icon-${ANDROID_SIZE}x${ANDROID_SIZE}.png`;

  if (!resizeIcon(source, ANDROID_SIZE, `${folders.android}/${androidName}`)) {
    iconsLogger.error(`Aborting: could not generate ${bundleId}/android/${androidName}`);
    return null;
  }

  counters.android += 1;
  iconsLogger.successCompact(`android/${androidName}`);

  // Copied under the canonical name, never the source one: `update-preset.js`
  // declares these two slots by name, so a project free to call its inputs
  // `bg-432.png` would otherwise have every Android export refused.
  for (const {source: element, name} of adaptive) {
    if (!fs.existsSync(element)) {
      iconsLogger.error(`Aborting: adaptive element does not exist: ${element}`);
      return null;
    }

    shell.cp(element, `${folders.android}/${name}`);
    counters.android += 1;
    iconsLogger.successCompact(`android/${name}`);
  }

  iconsLogger.step(2, `${bundleId}: desktop icons`);

  const desktopPng = `${folders.desktop}/icon.png`;

  if (!resizeIcon(desktopSource, DESKTOP_SIZE, desktopPng)) {
    iconsLogger.error(`Aborting: could not generate ${bundleId}/desktop/icon.png`);
    return null;
  }

  counters.desktop += 1;
  iconsLogger.successCompact('desktop/icon.png');

  if (!buildIco(desktopSource, `${folders.desktop}/icon.ico`, iconsLogger)) {
    return null;
  }

  counters.desktop += 1;
  iconsLogger.successCompact('desktop/icon.ico');

  const icnsPath = `${folders.desktop}/icon.icns`;

  if (!buildIcns(desktopSource, icnsPath, iconsLogger)) {
    return null;
  }

  if (fs.existsSync(icnsPath)) {
    counters.desktop += 1;
    iconsLogger.successCompact('desktop/icon.icns');
  }

  iconsLogger.step(3, `${bundleId}: web icons`);

  for (const size of WEB_SIZES) {
    const name = `pwa-${size}x${size}.png`;

    if (!resizeIcon(source, size, `${folders.web}/${name}`)) {
      iconsLogger.error(`Aborting: could not generate ${bundleId}/web/${name}`);
      return null;
    }

    counters.web += 1;
    iconsLogger.successCompact(`web/${name}`);
  }

  return counters;
};

// -----------------------------------------------------------------------------

const generateIcons = (config, bundles) => {
  const {input, output, base, background, foreground, desktop} = config;

  if (!ensureImageMagick(iconsLogger)) {
    return false;
  }

  const source = `${input}/${base}`;

  if (!fs.existsSync(source)) {
    iconsLogger.error(`Input base does not exist: ${source}`);
    return false;
  }

  const desktopSource = desktop ? `${input}/${desktop}` : source;

  if (!fs.existsSync(desktopSource)) {
    iconsLogger.error(`Desktop base does not exist: ${desktopSource}`);
    return false;
  }

  const adaptive = background
    ? [
        {source: `${input}/${background}`, name: 'adaptive-background.png'},
        {source: `${input}/${foreground}`, name: 'adaptive-foreground.png'}
      ]
    : [];

  const declaredBundles = bundles || config.bundles;
  const bundleIds = Object.keys(declaredBundles || {});

  if (bundleIds.length === 0) {
    iconsLogger.warn(`No bundle declared: generating under "${FALLBACK_BUNDLE_ID}"`);
    bundleIds.push(FALLBACK_BUNDLE_ID);
  }

  const root = generatedRoot(output);

  iconsLogger.log(`Generating from ${base}`);
  iconsLogger.data({input: source, output: root, bundles: bundleIds.join(', ')});

  const totals = {ios: 0, android: 0, desktop: 0, web: 0};

  for (const bundleId of bundleIds) {
    const counters = generateBundle({bundleId, root, source, desktopSource, adaptive});

    if (!counters) {
      return false;
    }

    for (const platform of PLATFORMS) {
      totals[platform] += counters[platform];
    }
  }

  iconsLogger.data(totals);
  iconsLogger.done(`icons created for ${bundleIds.length} bundle(s)`);
  return true;
};

// -----------------------------------------------------------------------------

export default generateIcons;
