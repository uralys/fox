// -----------------------------------------------------------------------------
// THE single reader of the `publish` block of fox.config.json.
//
// The block is keyed by the two axes, target first: a store is a lasting thing
// with credentials of its own, an env is a build that passes through it.
//
//   "publish": {
//     "steam": {
//       "login": "someone",
//       "envs": {
//         "release": {"appId": "1", "depots": {...}, "branch": ""},
//         "demo":    {"appId": "2", "depots": {...}, "branch": "staging"}
//       }
//     },
//     "itch": {"user": "someone", "game": "some-game", "envs": {"demo": {}}}
//   }
//
// The pre-target shape (`publish.steam` + `publish.steamDemo`, each flat) is still
// read: it said "the full game on Steam" and "the demo on Steam" with no way to
// name a second store, which is exactly the confusion the target axis removes.
// -----------------------------------------------------------------------------

export const SUPPORTED_TARGETS = ['steam', 'itch'];

export const TARGET_CHOICES = [
  {name: 'steam', value: 'steam'},
  {name: 'itch.io', value: 'itch'}
];

// Where `fox export` puts a build, and therefore where a publisher reads it:
// content first, store second — a demo is built once as a demo, then dressed for
// each store it goes to.
export const exportRoot = (env, target) => `export/${env}/${target}`;

// -----------------------------------------------------------------------------

const LEGACY_STEAM_KEY_BY_ENV = {
  release: 'steam',
  staging: 'steam',
  demo: 'steamDemo'
};

const isLegacySteam = (publish) =>
  Boolean(publish) &&
  SUPPORTED_TARGETS.every((target) => !(publish[target] && publish[target].envs));

// Returns the store settings for one (target, env) pair, always an object so a
// caller can read a missing key without guarding. `credentials` holds what belongs
// to the STORE (a Steam login, an itch user), `envs[env]` what belongs to this
// particular build (an app id, depots, a branch).
export const readPublishConfig = ({publish}, target, env) => {
  if (!publish) {
    return {};
  }

  if (target === 'steam' && isLegacySteam(publish)) {
    const legacy = publish[LEGACY_STEAM_KEY_BY_ENV[env] || 'steam'];
    return legacy ? {...legacy} : {};
  }

  const store = publish[target];

  if (!store) {
    return {};
  }

  const {envs, ...credentials} = store;
  const forEnv = (envs && envs[env]) || {};

  return {...credentials, ...forEnv};
};

// Declaring an env under a store says "this build belongs to that app" — which is
// what a Steam app id is for, and a `debug` build wants one to test Steam features
// locally. Being PUBLISHABLE is the stricter question, and it is answered by the
// upload slots: no depots and no channels means nothing to upload, so the env is
// never offered by `fox publish`.
const hasUploadSlots = (forEnv) => Boolean(forEnv && (forEnv.depots || forEnv.channels));

export const publishableEnvs = ({publish}, target) => {
  if (!publish) {
    return [];
  }

  if (target === 'steam' && isLegacySteam(publish)) {
    return Object.keys(LEGACY_STEAM_KEY_BY_ENV).filter((env) =>
      hasUploadSlots(publish[LEGACY_STEAM_KEY_BY_ENV[env]])
    );
  }

  const store = publish[target];

  if (!store || !store.envs) {
    return [];
  }

  return Object.keys(store.envs).filter((env) => hasUploadSlots(store.envs[env]));
};

export const publishableTargets = (settings) =>
  SUPPORTED_TARGETS.filter((target) => publishableEnvs(settings, target).length > 0);
