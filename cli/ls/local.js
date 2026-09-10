// -----------------------------------------------------------------------------
// The local half of every listing: what sits in an export folder, read from the
// bytes rather than from the repo.
//
// Both stores upload folder by folder — a Steam depot, an itch channel — so both
// are read the same way here, and only the confrontation with the remote side
// differs (steam.js, itch.js).

import fs from 'node:fs';
import path from 'node:path';

// -----------------------------------------------------------------------------

import { findPck, formatStamp, newestMtime, readBakedBundle, sha256 } from '../bundler/baked-bundle.js';
import { envChip } from '../bundler/export.js';

// -----------------------------------------------------------------------------

export const SHORT_SHA = 12;

// A notarized macOS export ships as an archive: the payload is in there, but
// saying "version unknown" would read as a broken export rather than as a
// format this listing does not open.
const ARCHIVE_EXTENSIONS = ['.zip', '.dmg'];

// -----------------------------------------------------------------------------
// `slots` maps a store-side name to a folder under the content root: a depot id
// on Steam, a channel name on itch.

export const readLocalSlots = (contentRoot, slots) =>
  Object.entries(slots).map(([slot, folder]) => {
    const slotPath = path.resolve(contentRoot, folder);

    if (!fs.existsSync(slotPath)) {
      return { slot, folder, missing: true };
    }

    const files = fs.readdirSync(slotPath).filter((file) => !file.startsWith('.'));

    if (!files.length) {
      return { slot, folder, empty: true };
    }

    const { version, env } = readBakedBundle(slotPath, files);
    const pck = findPck(slotPath, files);

    return {
      slot,
      folder,
      version,
      env,
      pck,
      archive: files.find((file) => ARCHIVE_EXTENSIONS.some((extension) => file.endsWith(extension))),
      sha: pck ? sha256(path.join(slotPath, pck)) : null,
      exportedAt: newestMtime(slotPath, files),
    };
  });

// -----------------------------------------------------------------------------

export const localLine = (slot) => {
  if (slot.missing) {
    return 'never exported';
  }

  if (slot.empty) {
    return 'empty folder';
  }

  if (!slot.version && slot.archive) {
    return `${slot.archive} — archive not read — exported ${formatStamp(slot.exportedAt)}`;
  }

  const chip = slot.env ? ` ${envChip(slot.env)}` : '';
  const short = slot.sha ? ` ${slot.sha.slice(0, SHORT_SHA)}` : '';

  return `${slot.version || 'version unknown'}${chip} — exported ${formatStamp(slot.exportedAt)}${short}`;
};

// -----------------------------------------------------------------------------
// The versions the local folders agree on — plural is the interesting case, and
// it is what tells a half-finished export from a coherent one.

export const localVersions = (slots) => [
  ...new Set(slots.filter((slot) => slot.version).map(({ version }) => version)),
];

export const warnOnLocalVersions = (logger, slots, projectVersion, label) => {
  const versions = localVersions(slots);

  if (versions.length > 1) {
    logger.warn(`${label}: folders disagree on the version: ${versions.join(', ')}`);
    return;
  }

  if (versions.length === 1 && versions[0] !== projectVersion) {
    logger.warn(`${label}: export is ${versions[0]} while project.godot is ${projectVersion}`);
  }
};
