// -----------------------------------------------------------------------------
// `export.before`: the commands a game runs right before Godot is invoked.
// -----------------------------------------------------------------------------
// A game often has to GENERATE something that must agree with the build about to
// leave: a file stamped with the version, a manifest, an asset pass. Running it
// by hand works until the day nobody thinks about it, and then the build ships
// with the previous version's answer inside — silently, because a stale generated
// file looks exactly like a fresh one.
//
// So the game declares those commands, and the exporter runs them itself:
//
//   "export": {
//     "before": ["python3 tools/stamp-version.py --apply"]
//   }
//
// They run at the ONE moment that works (see export.js): after the version is
// resolved — `tagVersion()` bumps it in the middle of the run, so anything
// reading it earlier reads the previous one — and before the first bake, so a
// refusal costs nothing. A non-zero exit ABORTS the export: a hook is there to
// say "not like that", and a hook that could only warn would be a comment.
//
// Each command is run through a shell, from the project root, with the build it
// is generating for in its environment:
//
//   FOX_ENV=demo  FOX_TARGET=itch  FOX_VERSION=0.26.9
//   FOX_PLATFORMS=Web  FOX_BUNDLE_ID=corridors
//
// Their output is inherited rather than captured: the whole point of a refusal is
// that its own message reaches the person exporting.
// -----------------------------------------------------------------------------

import { spawnSync } from 'node:child_process';

// -----------------------------------------------------------------------------

import { hooksLogger } from '../logger.js';

// -----------------------------------------------------------------------------

const hookEnv = ({ env, target, version, platforms, bundleId }) => ({
  ...process.env,
  FOX_ENV: env,
  FOX_TARGET: target,
  FOX_VERSION: version,
  FOX_PLATFORMS: platforms.join(','),
  FOX_BUNDLE_ID: bundleId,
});

// -----------------------------------------------------------------------------

// A malformed entry is refused rather than skipped: a hook silently ignored is
// the exact failure this feature exists to prevent.
const verifyHooks = (hooks) => {
  if (!Array.isArray(hooks)) {
    hooksLogger.error('export.before must be an array of commands');
    return false;
  }

  const invalid = hooks.find((hook) => typeof hook !== 'string' || !hook.trim());

  if (invalid !== undefined) {
    hooksLogger.error(`export.before holds something that is not a command: ${JSON.stringify(invalid)}`);
    return false;
  }

  return true;
};

// -----------------------------------------------------------------------------

const runBeforeExportHooks = (settings, context) => {
  const hooks = settings.export?.before ?? [];

  if (!Array.isArray(hooks) || hooks.length === 0) {
    return verifyHooks(hooks);
  }

  if (!verifyHooks(hooks)) {
    return false;
  }

  hooksLogger.log(`Running ${hooks.length} "before" hook(s) for ${context.env} on ${context.target}`);

  const env = hookEnv(context);

  for (const hook of hooks) {
    hooksLogger.log(hook);

    const { status, error } = spawnSync(hook, { shell: true, stdio: 'inherit', env });

    // A command that never started (empty shell, missing binary) reports no
    // status at all: treating that as a pass would ship exactly what the hook
    // was there to prevent.
    if (error) {
      hooksLogger.error(`Could not run: ${hook}`);
      hooksLogger.error(error.message);
      return false;
    }

    if (status !== 0) {
      hooksLogger.error(`Hook failed (exit ${status}): ${hook}`);
      return false;
    }
  }

  hooksLogger.success('Hooks passed');

  return true;
};

// -----------------------------------------------------------------------------

export { runBeforeExportHooks };
