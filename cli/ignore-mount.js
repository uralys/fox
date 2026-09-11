// -----------------------------------------------------------------------------
// keeping `addons/fox` out of a game's git history
// -----------------------------------------------------------------------------
// The mount is a dependency, and the two commands that own it treat it as one:
// `fox upgrade` deletes the folder whole before laying the next version down,
// and `fox link` replaces it with a symlink. A game tracking those files sees
// the first as a wall of modifications it never wrote, and the second as every
// file under the mount deleted at once, which is a commit away from losing the
// runtime for everyone.
//
// So the mount is ignored, and `core.fox` holds the version instead. The line
// is written here rather than left to a paragraph of the install guide: a
// newcomer meets this problem on their first `git status`, before ever reading
// about it.
// -----------------------------------------------------------------------------

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

import { ADDON_MOUNT } from './resolve-fox-mount.js';

// -----------------------------------------------------------------------------

const IGNORE_FILE = '.gitignore';
// No trailing slash, and that is not a detail: a directory pattern matches a
// directory, and `fox link` makes the mount a SYMLINK. `addons/fox/` would leave
// a linked game reporting its mount as untracked, which is the very case this
// line exists to silence.
const IGNORE_PATTERN = ADDON_MOUNT;

const IGNORE_BLOCK = [
  '# The Fox runtime is a dependency, mounted by `fox upgrade` and `fox link`.',
  '# The version this game runs is pinned in fox.config.json, as core.fox.',
  IGNORE_PATTERN,
  '',
].join('\n');

// -----------------------------------------------------------------------------

// `git` is asked rather than the file parsed: an ignore can come from a parent
// `.gitignore`, from `.git/info/exclude` or from the user's global one, and a
// pattern written here on top of any of those would be noise.
const git = (projectRoot, args) => {
  try {
    return {
      ok: true,
      output: execFileSync('git', ['-C', projectRoot, ...args], {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
      }),
    };
  } catch {
    return { ok: false, output: '' };
  }
};

// -----------------------------------------------------------------------------

// Both spellings are asked, because neither alone answers every case:
//
//   - `--no-index` throughout, since `check-ignore` calls a TRACKED path not
//     ignored whatever the rules say, and the games needing this line are
//     exactly the ones still tracking their mount;
//   - the plain path misses a `addons/fox/` pattern when the mount is ABSENT,
//     a fresh clone being the whole point of the restore;
//   - the trailing slash is `fatal: beyond a symbolic link` once the mount is
//     LINKED, which is the other case this exists for.
//
// The plain path answers first and covers a symlink, so the slash form only
// ever runs when there is no symlink in the way.
const isIgnored = (projectRoot) =>
  git(projectRoot, ['check-ignore', '-q', '--no-index', ADDON_MOUNT]).ok ||
  git(projectRoot, ['check-ignore', '-q', '--no-index', `${ADDON_MOUNT}/`]).ok;

// -----------------------------------------------------------------------------

const ignoreMount = (projectRoot, logger) => {
  if (!git(projectRoot, ['rev-parse', '--is-inside-work-tree']).ok) {
    return;
  }

  const tracked = git(projectRoot, ['ls-files', ADDON_MOUNT]).output.trim();

  if (!isIgnored(projectRoot)) {
    const ignorePath = path.join(projectRoot, IGNORE_FILE);
    const current = fs.existsSync(ignorePath) ? fs.readFileSync(ignorePath, 'utf8') : '';

    // The blank line separates the block from what was there, and there is
    // nothing to separate it from in a file that did not exist a second ago.
    const base = current.trim() ? `${current.replace(/\n*$/, '\n')}\n` : '';

    fs.writeFileSync(ignorePath, `${base}${IGNORE_BLOCK}`);
    logger.log(`Ignoring ${IGNORE_PATTERN} in ${IGNORE_FILE}`);
  }

  // An ignore says nothing about a file git already follows: the mount stays
  // tracked, and stays noisy, until it leaves the index. That is the one step
  // Fox will not take for anyone, since staging hundreds of deletions in
  // somebody else's working tree is not a side effect an install may have.
  if (tracked) {
    const count = tracked.split('\n').length;

    logger.warn(
      `${count} ${count === 1 ? 'file' : 'files'} of ${ADDON_MOUNT} still tracked: git ignores nothing it already follows`,
    );
    logger.log(`Drop them from the index once: git rm -r --cached ${ADDON_MOUNT}`);
  }
};

// -----------------------------------------------------------------------------

export { IGNORE_PATTERN, ignoreMount };
