// -----------------------------------------------------------------------------
// Godot bakes ProjectSettings into `project.binary` inside the PCK, so the
// version and env of an exported payload are readable from the bytes on disk,
// and NOT from the repo — which may have moved on since that export. Two
// commands read them: `fox publish` confirms what it is about to upload, and
// `fox ls` compares an installed build against what sits in the export folder.

import crypto from 'crypto';
import fs from 'fs';
import path from 'path';

// -----------------------------------------------------------------------------
// A setting is stored as: [nameLen int32][name][valueSize int32][type int32]
// [len int32][bytes]. Names are NOT padded, so the value of `bundle/env` starts
// a fixed 12 bytes past the end of the key, and its length is declared rather
// than guessed. Reading that length is what separates `demo` from `demo` plus
// whatever byte happens to follow it, and it also settles `bundle/version` vs
// `bundle/versionCode` on its own: only the right key lands on a String header.

const STRING_VARIANT = 4;
const MAX_VALUE_LENGTH = 64;

const readBakedValue = (buffer, key) => {
  const needle = Buffer.from(`bundle/${key}`, 'latin1');
  const header = needle.length + 4;

  let at = buffer.indexOf(needle);

  while (at >= 0) {
    if (at + header + 8 <= buffer.length) {
      const type = buffer.readUInt32LE(at + header);
      const length = buffer.readUInt32LE(at + header + 4);

      if (type === STRING_VARIANT && length > 0 && length < MAX_VALUE_LENGTH) {
        return buffer.toString('latin1', at + header + 8, at + header + 8 + length);
      }
    }

    at = buffer.indexOf(needle, at + 1);
  }

  return null;
};

// -----------------------------------------------------------------------------
// The PCK is what an installed build and an export folder can be compared on:
// export templates and signatures make the executable differ where the payload
// does not. On macOS it hides inside the .app bundle, which is a folder — so a
// depot listing alone never sees it.

const findPck = (depotPath, files) => {
  const direct = files.find((file) => file.endsWith('.pck'));

  if (direct) {
    return direct;
  }

  const bundle = files.find((file) => file.endsWith('.app'));

  if (!bundle) {
    return null;
  }

  const resources = path.join(bundle, 'Contents', 'Resources');

  try {
    const inner = fs.readdirSync(path.join(depotPath, resources)).find((file) => file.endsWith('.pck'));
    return inner ? path.join(resources, inner) : null;
  } catch (e) {
    return null;
  }
};

// The settings are baked into the PCK, and into the binary itself when the
// export embeds them.
const EMBEDDED_EXTENSIONS = ['.exe', '.x86_64'];

const readBakedBundle = (depotPath, files) => {
  const scanned = findPck(depotPath, files) || EMBEDDED_EXTENSIONS.map((extension) =>
    files.find((file) => file.endsWith(extension))
  ).find(Boolean);

  if (!scanned) {
    return {version: null, env: null};
  }

  try {
    const buffer = fs.readFileSync(path.join(depotPath, scanned));
    return {
      version: readBakedValue(buffer, 'version'),
      env: readBakedValue(buffer, 'env')
    };
  } catch (e) {
    return {version: null, env: null};
  }
};

// -----------------------------------------------------------------------------

const newestMtime = (depotPath, files) => {
  const stamps = files
    .map((file) => {
      try {
        return fs.statSync(path.join(depotPath, file)).mtime.getTime();
      } catch (e) {
        return null;
      }
    })
    .filter(Boolean);

  return stamps.length ? new Date(Math.max(...stamps)) : null;
};

const formatStamp = (stamp) => {
  if (!stamp) {
    return 'unknown';
  }

  const local = new Date(stamp.getTime() - stamp.getTimezoneOffset() * 60000);
  return local.toISOString().slice(0, 16).replace('T', ' ');
};

// -----------------------------------------------------------------------------

const sha256 = (filePath) => {
  try {
    return crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
  } catch (e) {
    return null;
  }
};

// -----------------------------------------------------------------------------

export {readBakedBundle, newestMtime, formatStamp, findPck, sha256};
