// -----------------------------------------------------------------------------
// Where the working tree stands relative to the tag a version names.
//
// Every listing and every export reads the version from project.godot, and that
// number only changes when `fox tag` runs. Commits landed after the tag are
// therefore INVISIBLE in the version: two different trees answer "1.2.3", and a
// build made from the later one is silently reported as the tagged release.
// This module measures that gap so the callers can say it out loud.

import shell from 'shelljs';

// -----------------------------------------------------------------------------

const git = (command) => {
  const { code, stdout } = shell.exec(`git ${command}`, { silent: true });
  return code === 0 ? stdout.trim() : null;
};

// -----------------------------------------------------------------------------

export const readTagState = (version) => {
  if (!version || git('rev-parse --is-inside-work-tree') !== 'true') {
    return null;
  }

  const tag = `v${version}`;

  if (git(`rev-parse --verify --quiet refs/tags/${tag}`) === null) {
    return { tag, tagged: false, ahead: 0, dirty: git('status --porcelain') !== '' };
  }

  return {
    tag,
    tagged: true,
    branch: git('rev-parse --abbrev-ref HEAD'),
    ahead: Number.parseInt(git(`rev-list --count ${tag}..HEAD`) || '0', 10),
    dirty: git('status --porcelain') !== '',
  };
};

// -----------------------------------------------------------------------------
// One sentence, and the flag saying whether it deserves a warning: a tree that
// sits exactly on its tag is the only quiet case.

export const tagStateLine = (state) => {
  if (!state) {
    return null;
  }

  const dirt = state.dirty ? ', uncommitted changes' : '';

  if (!state.tagged) {
    return { clean: false, message: `${state.tag} is not tagged yet${dirt}` };
  }

  if (!state.ahead) {
    return { clean: !state.dirty, message: `${state.branch} is on ${state.tag}${dirt}` };
  }

  const commits = state.ahead === 1 ? 'commit' : 'commits';

  return {
    clean: false,
    message: `${state.branch} is ${state.ahead} ${commits} ahead of ${state.tag}${dirt}: the version below does NOT describe them`,
  };
};
