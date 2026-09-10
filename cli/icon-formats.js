// -----------------------------------------------------------------------------
// desktop icon containers: Windows `.ico` and macOS `.icns`
// requires ImageMagick, see docs/install.md
// -----------------------------------------------------------------------------
// `magick out.icns` writes a PNG wearing an `.icns` extension: the ICNS coder
// does not produce a real container. Only `iconutil -c icns` (macOS only) does,
// so the `.icns` output is skipped with a warning on every other platform.
// -----------------------------------------------------------------------------

import fs from 'fs';
import os from 'os';
import path from 'path';
import shell from 'shelljs';
import {quote, runMagick} from './imagemagick.js';

// -----------------------------------------------------------------------------

const ICO_FRAMES = [256, 128, 64, 48, 32, 16];

// `iconutil` reads a fixed set of file names; anything else is ignored.
const ICONSET_SLOTS = [
  {name: 'icon_16x16.png', size: 16},
  {name: 'icon_16x16@2x.png', size: 32},
  {name: 'icon_32x32.png', size: 32},
  {name: 'icon_32x32@2x.png', size: 64},
  {name: 'icon_128x128.png', size: 128},
  {name: 'icon_128x128@2x.png', size: 256},
  {name: 'icon_256x256.png', size: 256},
  {name: 'icon_256x256@2x.png', size: 512},
  {name: 'icon_512x512.png', size: 512},
  {name: 'icon_512x512@2x.png', size: 1024}
];

// -----------------------------------------------------------------------------

const buildIco = (input, output, logger) => {
  const created = runMagick(
    [
      quote(input),
      '-define',
      `icon:auto-resize=${ICO_FRAMES.join(',')}`,
      quote(output)
    ],
    logger
  );

  if (!created) {
    logger.error(`Aborting: could not generate ${path.basename(output)}`);
    return false;
  }

  return true;
};

// -----------------------------------------------------------------------------

const buildIcns = (input, output, logger) => {
  if (!shell.which('iconutil')) {
    logger.warn(`\`iconutil\` not found: skipping ${path.basename(output)}`);
    logger.warn('A real .icns container can only be built on macOS');
    return true;
  }

  const workdir = fs.mkdtempSync(path.join(os.tmpdir(), 'fox-icns-'));
  const iconset = path.join(workdir, 'icon.iconset');
  shell.mkdir('-p', iconset);

  for (const slot of ICONSET_SLOTS) {
    const created = runMagick(
      [
        quote(input),
        '-resize',
        quote(`${slot.size}x${slot.size}`),
        '-unsharp',
        '1x4',
        quote(path.join(iconset, slot.name))
      ],
      logger
    );

    if (!created) {
      shell.rm('-rf', workdir);
      logger.error(`Aborting: could not generate the ${slot.name} iconset slot`);
      return false;
    }
  }

  const result = shell.exec(
    `iconutil -c icns ${quote(iconset)} -o ${quote(output)}`,
    {silent: true}
  );

  shell.rm('-rf', workdir);

  if (result.code !== 0) {
    logger.error(`iconutil failed (code ${result.code})`);

    const details = (result.stderr || result.stdout || '').trim();
    if (details) {
      logger.error(details);
    }

    logger.error(`Aborting: could not generate ${path.basename(output)}`);
    return false;
  }

  return true;
};

// -----------------------------------------------------------------------------

export {buildIcns, buildIco};
