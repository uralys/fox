# `env` and `target` — the two axes of a build

A build answers two questions, and fox keeps them apart because they change
independently.

| Axis | Setting | Values | Answers |
|---|---|---|---|
| `env` | `bundle/env` | `debug`, `demo`, `release` | what the build **contains** |
| `target` | `bundle/target` | `steam`, `itch` | where it is **published**, and which store plumbing it carries |

They cross freely. The same `demo` content ships to Steam with an app id, an
overlay and a Workshop, and to itch.io with none of them. A value that means
"the demo on Steam" belongs to neither axis, and putting one in either is the
mistake this split exists to prevent: it makes a second store impossible to name
without inventing a fake env.

## In a project

**Presets** declare both axes, and fox picks one on `platform + env + target`:

```ini
custom_features="env:demo,target:itch"
export_path="export/demo/itch/windows/my-game.exe"
```

Builds land under `export/<env>/<target>/<platform>/`: a build is made once for
what it contains, then dressed for each store it goes to.

A preset declaring `env:` alone still matches every target, so a project that
never had a second store keeps working untouched — and `bundle/target` defaults
to `steam` when the project does not declare it.

**`fox.config.json`** is keyed store first, because credentials belong to the
store and a build merely passes through it:

```json
"publish": {
  "steam": {
    "login": "partner-login",
    "envs": {
      "release": {"appId": "1", "depots": {"11": "windows"}, "branch": ""},
      "demo":    {"appId": "2", "depots": {"21": "windows"}, "branch": "staging"},
      "debug":   {"appId": "1"}
    }
  },
  "itch": {
    "user": "someone",
    "game": "some-game",
    "envs": {"demo": {"channels": {"windows-demo": "windows"}}}
  }
}
```

Declaring an env under a store says *this build belongs to that app* — which is
why `debug` can carry an app id and init Steam locally. Being **publishable** is
the stricter question, answered by the upload slots: an env with neither
`depots` nor `channels` is never offered by `fox publish`.

An itch channel name carrying `windows` / `linux` / `osx` is what tells itch.io
which platform the upload is for.

## At runtime

```gdscript
G.ENV        # 'debug' | 'demo' | 'release'
G.TARGET     # 'steam' | 'itch'
G.isSteamTarget()
```

A **content** question reads `G.ENV` (is this the demo? which levels ship?).
A **store** question reads `G.TARGET` — never `G.ENV`. Initializing the Steam
SDK, showing a Workshop entry or opening the overlay are store questions.

## Commands

```sh
fox switch                    # asks env, then target
fox export                    # asks env, then target (target only when several exist)
fox publish [store] [env] [branch]
```

`fox publish demo staging` predates the target axis and still works: an argument
naming an env rather than a store is read as one, and Steam is assumed.
