// -----------------------------------------------------------------------------
// generates the boot splash frame: the very first image Godot paints, before
// any script runs (`application/boot_splash/image` in project.godot)
// requires ImageMagick, see docs/install.md
// -----------------------------------------------------------------------------
// One rule, three surfaces: the boot splash, the animated splash screen and the
// launch storyboard must show the SAME logo at the SAME size. The geometry is
// declared once, in `fox/components/splash/splash-screen.gd` (`BASE_CANVAS`,
// `LOGO_BASE_WIDTH`), and read from there — never redeclared here, or the three
// surfaces would drift apart at the first tweak. See docs/splash.md
// -----------------------------------------------------------------------------

import fs from 'fs';
import path from 'path';
import {ensureImageMagick, quote, runMagick} from './imagemagick.js';
import {splashLogger} from './logger.js';

// -----------------------------------------------------------------------------

const SPLASH_SCREEN_SOURCE = 'fox/components/splash/splash-screen.gd';

const DEFAULT_LOGO = 'res://fox/assets/splash/logo-uralys.png';
const DEFAULT_OUTPUT = 'assets/generated/boot-splash.png';

// `boot_splash/bg_color` defaults to black: the generated frame must sit on the
// same colour, or a seam shows during the handoff to the animated splash.
const DEFAULT_BACKGROUND = '#000000';

const CANVAS_PATTERN = /const\s+BASE_CANVAS\s*:?=\s*Vector2\s*\(\s*([\d.]+)\s*,\s*([\d.]+)\s*\)/;
const LOGO_WIDTH_PATTERN = /const\s+LOGO_BASE_WIDTH\s*:?=\s*([\d.]+)/;

// -----------------------------------------------------------------------------

const resolveResPath = (value, projectRoot) =>
  value.startsWith('res://')
    ? path.join(projectRoot, value.slice('res://'.length))
    : path.resolve(projectRoot, value);

// -----------------------------------------------------------------------------

// Guessing a canvas or a logo width would silently produce a frame that no
// longer matches the animated splash: a parsing failure is an abort, never a
// fallback.
const readSplashGeometry = (projectRoot) => {
  const source = path.join(projectRoot, SPLASH_SCREEN_SOURCE);

  if (!fs.existsSync(source)) {
    splashLogger.error(`Aborting: splash doctrine not found at ${source}`);
    return null;
  }

  const content = fs.readFileSync(source, 'utf8');

  const canvas = CANVAS_PATTERN.exec(content);
  if (!canvas) {
    splashLogger.error(`Aborting: could not read BASE_CANVAS in ${SPLASH_SCREEN_SOURCE}`);
    return null;
  }

  const logoWidth = LOGO_WIDTH_PATTERN.exec(content);
  if (!logoWidth) {
    splashLogger.error(`Aborting: could not read LOGO_BASE_WIDTH in ${SPLASH_SCREEN_SOURCE}`);
    return null;
  }

  return {
    width: Math.round(Number(canvas[1])),
    height: Math.round(Number(canvas[2])),
    logoWidth: Math.round(Number(logoWidth[1]))
  };
};

// -----------------------------------------------------------------------------

const generateBootSplash = (config = {}) => {
  const projectRoot = config.projectRoot || process.cwd();

  const {
    input = DEFAULT_LOGO,
    output = DEFAULT_OUTPUT,
    backgroundColor = DEFAULT_BACKGROUND
  } = config;

  if (!ensureImageMagick(splashLogger)) {
    return false;
  }

  const geometry = readSplashGeometry(projectRoot);
  if (!geometry) {
    return false;
  }

  const logoFile = resolveResPath(input, projectRoot);
  if (!fs.existsSync(logoFile)) {
    splashLogger.error(`Aborting: logo does not exist: ${logoFile}`);
    return false;
  }

  const outputFile = resolveResPath(output, projectRoot);
  fs.mkdirSync(path.dirname(outputFile), {recursive: true});

  const canvas = `${geometry.width}x${geometry.height}`;

  splashLogger.log('Generating boot splash');
  splashLogger.data({
    input: logoFile,
    output: outputFile,
    canvas,
    logoWidth: geometry.logoWidth,
    backgroundColor
  });

  // `contain`: the logo keeps its ratio and never exceeds the canvas height,
  // exactly like the animated splash sizes it at runtime.
  const created = runMagick(
    [
      '-size',
      quote(canvas),
      `xc:${quote(backgroundColor)}`,
      '\\(',
      quote(logoFile),
      '-resize',
      quote(`${geometry.logoWidth}x${geometry.height}`),
      '\\)',
      '-gravity',
      'center',
      '-composite',
      '-depth',
      '8',
      quote(outputFile)
    ],
    splashLogger
  );

  if (!created) {
    splashLogger.error('Aborting: could not compose the boot splash frame');
    return false;
  }

  splashLogger.done(`boot splash created: ${canvas}, logo ${geometry.logoWidth}px wide`);
  return true;
};

// -----------------------------------------------------------------------------

export default generateBootSplash;
