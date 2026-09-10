// -----------------------------------------------------------------------------
// `fox ls` lists what is exported and confronts it with what is actually shipped,
// one store at a time: `ls:steam` against the Steam Deck, `ls:itch` against the
// itch.io page. `fox ls` alone runs every store the project publishes to.
//
// A store that is unreachable never fails the listing — each half prints what it
// could read and says why the rest is missing.

import { publishableTargets } from '../bundler/publish-config.js';
import { readProjectVersion } from '../bundler/tag.js';
import { foxLogger } from '../logger.js';
import lsItch from './itch.js';
import lsSteam from './steam.js';

// -----------------------------------------------------------------------------

const LISTERS = {
  steam: lsSteam,
  itch: lsItch,
};

// -----------------------------------------------------------------------------

const ls = async (settings, target) => {
  const { core, publish } = settings;

  const projectVersion = readProjectVersion();
  foxLogger.log(`${core.title} — project.godot is ${projectVersion}`);

  if (target) {
    return await LISTERS[target](settings, { projectVersion });
  }

  // Without a store named, list the ones the project actually publishes to
  // rather than all the ones fox knows about: an empty section reads as a
  // broken configuration.
  const targets = publishableTargets({ publish }).filter((name) => LISTERS[name]);

  if (!targets.length) {
    foxLogger.error('Nothing to list: fox.config.json declares no "publish.<store>"');
    return false;
  }

  for (const name of targets) {
    await LISTERS[name](settings, { projectVersion });
  }

  return true;
};

export default ls;
