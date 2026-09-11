#!/usr/bin/env -S node --no-warnings

// -----------------------------------------------------------------------------
// keep addons/fox/plugin.cfg on the version package.json just took
// -----------------------------------------------------------------------------
// Two files carry the version of this repository: `package.json`, which `npm
// version` bumps, and `addons/fox/plugin.cfg`, which is what a GAME reads. Only
// the first one was ever bumped, so v2.0.1 shipped an addon declaring 2.0.0.
//
// That is not cosmetic. `fox upgrade` compares the declared version against the
// release it is installing, so a stale `plugin.cfg` makes it reinstall on every
// single run, and the release job refuses to attach a zip whose tag and
// `plugin.cfg` disagree.
//
// Run by the `version` npm lifecycle script, which fires after the bump and
// BEFORE the commit: staging the file here puts it in the very commit `npm
// version` tags.
// -----------------------------------------------------------------------------

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// -----------------------------------------------------------------------------

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const pluginConfig = path.join(root, 'addons', 'fox', 'plugin.cfg');

const { version } = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
const config = fs.readFileSync(pluginConfig, 'utf8');

const synced = config.replace(/^version=".*"$/m, `version="${version}"`);

if (synced === config) {
  console.log(`plugin.cfg already on ${version}`);
  process.exit(0);
}

fs.writeFileSync(pluginConfig, synced);
execFileSync('git', ['add', pluginConfig], { cwd: root });

console.log(`plugin.cfg synced to ${version}`);
