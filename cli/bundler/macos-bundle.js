// -----------------------------------------------------------------------------

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import shell from 'shelljs';

// -----------------------------------------------------------------------------
// The macOS preset exports a .zip holding the .app, because that is the only
// shape Godot can sign and notarize. A Steam depot ships what it is given: the
// folder uploaded untouched put a single archive in the depot, the launch
// option "<Game>.app" pointed at nothing, and Steamworks left "the default
// branch includes <Game>.app" unticked forever — on a build that no macOS
// player could have started anyway.
//
// So the archive is unfolded in place, right before the VDF is written. `unzip`
// restores the executable bit the binary needs, and the archive is removed
// afterwards so the depot never carries the same 90 MB twice. Once unfolded
// there is no archive left, which makes a second run a no-op.

const BUNDLE_EXTENSION = '.app';
const ARCHIVE_LISTING_BYTES = 4 * 1024 * 1024;

// The bundle is named after the game, which this reader has no business
// knowing: it is read back from the archive, as the single root entry ending
// in `.app`. An archive without one (a plain zipped build) is left alone.
const bundledApp = (archivePath) => {
  let listing;

  try {
    listing = execFileSync('unzip', ['-Z1', archivePath], {
      encoding: 'utf8',
      maxBuffer: ARCHIVE_LISTING_BYTES,
      stdio: ['ignore', 'pipe', 'ignore'],
    });
  } catch {
    return null;
  }

  const roots = new Set(listing.split('\n').map((entry) => entry.trim().split('/')[0]));
  return [...roots].find((entry) => entry.endsWith(BUNDLE_EXTENSION)) || null;
};

export default (contentRoot, folders, logger) => {
  for (const folder of Object.values(folders)) {
    const folderPath = path.resolve(contentRoot, folder);

    if (!fs.existsSync(folderPath)) {
      continue;
    }

    for (const archive of fs.readdirSync(folderPath).filter((file) => file.endsWith('.zip'))) {
      const archivePath = path.join(folderPath, archive);
      const bundle = bundledApp(archivePath);

      if (!bundle) {
        continue;
      }

      try {
        // A leftover bundle comes from an older export: keeping it would mix
        // two builds in one depot, so it goes before the fresh one lands.
        shell.rm('-rf', path.join(folderPath, bundle));
        execFileSync('unzip', ['-q', '-o', archivePath, '-d', folderPath], { stdio: ['ignore', 'ignore', 'pipe'] });
        fs.rmSync(archivePath);
      } catch (error) {
        logger.error(`could not unfold ${archive} in ${folder}: ${error.message}`);
        return false;
      }

      logger.log(`${folder}: unfolded ${archive} into ${bundle}`);
    }
  }

  return true;
};
