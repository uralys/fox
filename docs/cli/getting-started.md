# 🦊 the fox CLI

One command per step of a game's life: run it, import its assets, export a
bundle, upload it to a store, and check what actually ships.

<img title="exporting-illustration" height="270px"  src="../../assets/docs/cli-export.png"/>

- [requirements](#requirements)
- [installing the executable](#installing-the-executable)
- [mounting the runtime in a game](#mounting-the-runtime-in-a-game)
- [project detection](#project-detection)
- [commands](#commands)
- [passing options to Godot](#passing-options-to-godot)

Each family of commands has its own page:

| Topic | Page |
|---|---|
| run the game, hot reload, navigation state | [running your game](./hot-reload.md) |
| headless asset import | [importing assets](./import.md) |
| `fox upgrade`, `fox link`, the release notice | [pinning a version](./versioning.md) |
| build and export a bundle | [exporting](../exporting/export.md) |
| the `env` / `target` axes | [envs and targets](../exporting/envs-and-targets.md) |
| icons, splashscreens, screenshots, boot splash | [images generation](../exporting/images.md) |
| upload to Steam and itch.io | [publishing](../exporting/publish.md) |
| confront the local exports with the stores | [listing builds](../exporting/ls.md) |
| developing Fox itself | [contributing](../contributing.md) |

## requirements

NodeJS >= 26 for the CLI itself, and **ImageMagick 7** (the `magick` binary) for
the `fox generate:*` commands. Neither is a requirement of Fox itself: a game
mounting the addon without ever installing the CLI is fine, it just does its
upgrades and exports by hand.

```sh
brew install imagemagick
```

See [install](../install.md#prerequisites) for the full prerequisites table.

## installing the executable

One command, on macOS, Linux and Windows (Git Bash or WSL):

```sh
curl -fsSL https://raw.githubusercontent.com/uralys/fox/main/install.sh | sh
```

Run from a Godot project, it installs **both halves** of Fox: the runtime at
`addons/fox`, and the executable. Run anywhere else, the executable alone. See
[installing Fox](../install.md) for the whole walkthrough.

The CLI is **not published on the npm registry**: it is installed from the git
tag of a release, the same source of truth the addon is taken from, so the
executable and the runtime mounted in a game can never come from two different
trees. Typing that one line yourself works just as well:

```sh
npm install -g github:uralys/fox#v2.2.1
```

A version can be forced, to reproduce an old setup or to walk back a
regression:

```sh
curl -fsSL https://raw.githubusercontent.com/uralys/fox/main/install.sh | sh -s -- 2.2.0
```

From then on you never type any of this again: `fox upgrade` installs the CLI of
the version it pins, so the executable and the addon stay on the same Fox. See
[pinning a version](./versioning.md).

```sh
fox
```

The CLI is **optional**. It needs NodeJS >= 26, while the runtime needs nothing
but Godot, so a machine without NodeJS gets a warning rather than an error: the
installer mounts the addon and skips the executable.

⚠️ The executable is **global, one per machine**, while a mount is per project.
A `fox` sitting earlier in your `PATH` (a hand written symlink on a checkout, for
instance) shadows the one npm writes, and `fox upgrade` would look like it did
nothing: the installer and `fox upgrade` both name that file when they find it.

### why the URL says `main`

`main` names the **installer**, never the Fox it installs: the script starts by
reading the latest release and takes both halves from that tag, so piping it
from the default branch still pins a released version.

That is what keeps the entry point stable. A URL carrying a tag would have to be
rewritten in every page at each release, and anyone who kept an older copy of
that line would run an installer frozen in the past. The tagged form exists
anyway, for a CI job that wants the installer itself reproducible:

```sh
curl -fsSL https://raw.githubusercontent.com/uralys/fox/v2.3.0/install.sh | sh
```

It only answers from the first release that ships `install.sh`: the tags
published before it hold no such file.

Developing Fox itself is the other way round, and lives in
[contributing](../contributing.md).

## mounting the runtime in a game

The CLI is half of Fox. The other half is the runtime a game mounts at
`res://addons/fox`: the installer writes it when it is run from a project, and
`fox upgrade` writes it afterwards, from the same release.

```sh
cd your-game
fox upgrade
```

It works on a project that has no mount yet, which is why a newcomer never has
to clone anything. The Godot side of the setup (main scene, plugin, autoloads)
is in [install](../install.md).

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

- running the game and hot reloading it: [running your game](./hot-reload.md),
  which also documents the `r` and `ctrl + c` shortcuts
- `fox import`: [importing assets](./import.md)
- `fox upgrade` and `fox link`: [pinning a version](./versioning.md)
- `fox export`: [exporting](../exporting/export.md), and the two axes a build is
  made of, `env` and `target`, in
  [envs and targets](../exporting/envs-and-targets.md)
- `fox publish`: [publishing](../exporting/publish.md)
- `fox ls`, `fox ls:steam`, `fox ls:itch`: [listing builds](../exporting/ls.md)
- the five `fox generate:*` commands drive **ImageMagick 7**
  (`brew install imagemagick`, see [prerequisites](../install.md#prerequisites)),
  and where their output lands is described in
  [images generation](../exporting/images.md)

## passing options to Godot

Parameters unknown to fox are handed to Godot as they are.

```sh
fox run:game --headless --debug-collisions
```

See all available parameters on the
[Godot CLI Reference](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html#command-line-reference).
