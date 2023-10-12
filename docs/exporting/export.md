# exporting with CLI

To help export your presets you can use

```sh
fox export
```

This will ask which preset you want to use, update it if you need to change the version for example, and run Godot export.

## prepare the presets

you can start from the samples provided in `./fox/export_presets.sample.cfg` or install templates from Godot.

## export_path

This path is mandatory to build properly. This is the `<path>` parameter in the headless command.

```sh
--export <preset> <path>
```

You need to set it in your preset:

```ini
export_path=_build/server.pck
```

## env

Define if your preset is for `production`, `debug`, or `pck` by setting it a `custom_features`.

When exporting, it will apply `--export`, `--export-debug`, or `--export-pack`

example:

```ini
[preset.0]

name="Android Debug"
platform="Android"
custom_features="env:debug"
```

## version

You may use the current version, or update it before exporting.

`Fox` uses `npm version` which updates `package.json` and creates a `git tag`

Then this `version` is replaced in your preset property depending on the platform.

## bundle

**disclaimer**: I'm experimenting bundles for the different chapters in [Lockey Land](https://twitter.com/lockeylandgame), exported as separate applications.

By default 1 app = 1 bundle

You can configure `Fox` to export many apps built from a single project.

Each bundle must have its `uid`, can use another icon, a subtitle attached to the main application name etc...

### example in `fox.config.json`

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
