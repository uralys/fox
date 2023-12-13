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

Define if your preset is for `release`, `debug`, or `pack` by setting it a `custom_features`.

example:

```ini
[preset.0]

name="Android Debug"
platform="Android"
custom_features="env:debug"
include_filter="override.cfg"
```

Then, when exporting, it will apply Godot CLI option `--export-release`, `--export-debug`, or `--export-pack`.

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
