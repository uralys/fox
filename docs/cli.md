# 🦊 the fox CLI

One command per step of a game's life: run it, import its assets, export a
bundle, upload it to a store, and check what actually ships.

<img title="exporting-illustration" height="270px"  src="../assets/docs/cli-export.png"/>

- [requirements](#requirements)
- [installing the executable](#installing-the-executable)
- [project detection](#project-detection)
- [commands](#commands)
- [passing options to Godot](#passing-options-to-godot)

Each family of commands has its own page:

| Topic | Page |
|---|---|
| run the game, hot reload, navigation state | [running your game](./cli/hot-reload.md) |
| headless asset import | [importing assets](./cli/import.md) |
| `fox upgrade`, `fox link`, the release notice | [pinning a version](./cli/versioning.md) |
| build and export a bundle | [exporting](./exporting/export.md) |
| the `env` / `target` axes | [envs and targets](./exporting/envs-and-targets.md) |
| icons, splashscreens, screenshots, boot splash | [images generation](./exporting/images.md) |
| upload to Steam and itch.io | [publishing](./exporting/publish.md) |
| confront the local exports with the stores | [listing builds](./exporting/ls.md) |
| developing Fox itself | [contributing](./contributing.md) |

## requirements

NodeJS >= 26 for the CLI itself, and **ImageMagick 7** (the `magick` binary) for
the `fox generate:*` commands:

```sh
brew install imagemagick
```

See [install](./install.md#prerequisites) for the full prerequisites table.

## installing the executable

The CLI is not published on the npm registry: it is installed from the git tag
of a release, the same source of truth the addon is taken from.

```sh
npm install -g github:uralys/fox#v2.2.0
```

From then on you never type that line again: `fox upgrade` installs the CLI of
the version it pins, so the executable and the runtime mounted in your game stay
on the same Fox. See [pinning a version](./cli/versioning.md).

```sh
fox
```

⚠️ The executable is **global, one per machine**, while a mount is per project.
A `fox` sitting earlier in your `PATH` (a hand written symlink on a checkout, for
instance) shadows the one npm writes, and `fox upgrade` would look like it did
nothing: it names that file when it finds it.

Developing Fox itself is the other way round, and lives in
[contributing](./contributing.md).

## project detection

Every command starts by checking that the current folder is a game using Fox.
The probe is the runtime's `default.config.json`, looked up under the mount
holding it: `addons/fox/default.config.json` first, then the legacy `fox/`
mount for a game whose runtime has not been moved to `addons/` yet. Every other
runtime file the CLI reads (the boot splash sources included) is resolved the
same way, addon mount first.

When neither mount carries it, the command stops on:

```txt
<current folder> is not a project using Fox: no addons/fox/default.config.json
```

The error names the addon mount even for a legacy project, because that is
where the runtime is expected to live from now on. The legacy candidate is a
transition tolerance: it goes away once every game is migrated.

## commands

```ini
Usage: fox <command> [options]

Commands:
  fox run:editor                open Godot Editor with your main scene

  fox run:game                  start your game locally (watch + hot reload)

  fox import [--force]          import assets headless, as the editor does
                                when opening the project

  fox tag [patch|minor|major]   bump version in project.godot and create a
                                git tag

  fox upgrade [version]         pin addons/fox to a released version and
                                reimport (latest by default, --no-import
                                to skip)

  fox link [path-to-fox]        mount your local fox checkout in
                                addons/fox to follow it live, and reimport

  fox export                    export a bundle for one of your presets

  fox export:web                scriptable HTML5 export into _build/web,
                                NOT shippable (no bundle bake): use
                                `fox export` to ship a web build

  fox publish [store] [env]     upload exported builds to a store
                 [branch]       (steamcmd for steam, butler for itch)

  fox switch                    switch from a bundle to another (writes
                                override.cfg)

  fox ls                        list the local exports and confront them
                                with every store the project publishes to

  fox ls:steam                  confront the local Steam exports with the
                                builds installed on the Steam Deck

  fox ls:itch                   confront the local itch exports with the
                                builds live on the itch.io page

  fox generate:icons            generate icons, using a base 1200x1200 image

  fox generate:splashscreens    generate the iOS launch storyboard images,
                                extending a background color from a centered
                                base image

  fox generate:boot-splash      generate the boot splash frame Godot paints
                                before any script runs

  fox generate:screenshots      resize store screenshots to the required sizes

  fox generate:steam-screenshots  resize screenshots for the Steam store

  fox update-po-files           run msgmerge on the project .po translation
                                files (experimental)
```

- running the game and hot reloading it: [running your game](./cli/hot-reload.md),
  which also documents the `r` and `ctrl + c` shortcuts
- `fox import`: [importing assets](./cli/import.md)
- `fox upgrade` and `fox link`: [pinning a version](./cli/versioning.md)
- `fox export`: [exporting](./exporting/export.md), and the two axes a build is
  made of, `env` and `target`, in
  [envs and targets](./exporting/envs-and-targets.md)
- `fox publish`: [publishing](./exporting/publish.md)
- `fox ls`, `fox ls:steam`, `fox ls:itch`: [listing builds](./exporting/ls.md)
- the five `fox generate:*` commands drive **ImageMagick 7**
  (`brew install imagemagick`, see [prerequisites](./install.md#prerequisites)),
  and where their output lands is described in
  [images generation](./exporting/images.md)

## passing options to Godot

Parameters unknown to fox are handed to Godot as they are.

```sh
fox run:game --headless --debug-collisions
```

See all available parameters on the
[Godot CLI Reference](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html#command-line-reference).
