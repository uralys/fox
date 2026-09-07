# exporting with CLI

To quick export your presets you can use:

```sh
fox export
```

This will ask which preset you want to use, update it if you need to change the version for example, and run Godot export.

This command cannot work out of the box, you need to set up your presets and config before to use it.

Follow these requirements explained in the sections below:

- prepare the presets, keys and path with Godot
- define you `env`

Then you're all set! You can now use `fox export` to quickly export your project, following the prompt to select your preset from the CLI.

## prepare the presets

First, you need to install templates from Godot.

Use `Project > Export` and be sure to generate your `export_presets.cfg` without errors from Godot Editor.

The `Export path` will be generated from the preset name, `bundleId` and `env`

## define you `env`

Define if your preset is for `release`, `debug` by setting it a `custom_features`.

example:

```ini
[preset.0]

name="Android Debug"
platform="Android"
custom_features="env:debug"
include_filter="override.cfg"
```

Then, when exporting, it will apply Godot CLI option `--export-release` or `--export-debug` depending on the `env` you've set.

## additional options

### version

You may use the current version, or update it before exporting.

`Fox` uses `npm version` which updates `package.json` and creates a `git tag`

Then this `version` is replaced in your preset property depending on the platform.

### bundles

**disclaimer**: I've experimented bundles for the different chapters in [Lockey Land](https://uralys.com/lockeyland), exported as separate applications.

By default 1 app = 1 bundle --> `bundleId` is the same as the app name.

You can configure `Fox` to export many apps built from a single project.

Each bundle must have its `uid`, can use another icon, a subtitle attached to the main application name etc...

#### example in `fox.config.json`

```json
"bundles": {
  "app1": {
    "uid": "com.your.app1",
    "subtitle": "theme1",
    "Android": {
      "keystore/release_user": "admin-app1",
    }
  },
  "app2": {
    "uid": "com.your.app2",
    "subtitle": "theme2",
    "Android": {
      "keystore/release_user": "admin-app2",
    }
  }
}
```

## web (HTML5)

A `platform="Web"` preset is exported by `fox export` like any other platform: it
is offered in the platform prompt as soon as it declares the `env` and `target`
being exported, and `all` includes it.

```ini
[preset.12]

name="Web (itch.io)"
platform="Web"
custom_features="env:demo,target:itch"
export_path="export/demo/itch/web/index.html"
```

Two things differ, and they are handled by `fox`, not by the project:

- **no Steam app id.** A web build has no Steam client to talk to, and the id is
  only ever baked for `target:steam` anyway.
- **no `[custom]` secret.** The pck of an HTML5 build is downloaded by every
  visitor and readable with a text editor, so baking an HMAC key there publishes
  it rather than protecting anything. `fox export` refuses to, says so, and the
  build ships the committed (empty) values: the game is expected to degrade,
  e.g. read a leaderboard without writing to it.

What is baked stays baked: `[bundle] platform="Web" env=… target=…` lands in the
pck, so `fox publish` and `fox ls` read a web payload back exactly as they read a
depot.

Publishing it to itch is a `butler` channel like the others: add it under
`publish.itch.envs.<env>.channels`, mapped to the folder the preset writes:

```json
"channels": {"html5": "web", "windows-demo": "windows"}
```

⚠️ `fox export:web` is a different command with a different purpose: a scriptable
`--export-debug` that bakes nothing. It is for generated projects that just need
a playable page, never for a build handed to players.
