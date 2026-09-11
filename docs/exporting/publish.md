# 🚀 publishing to a store

```sh
fox publish              # asks the store, then the env, then the branch
fox publish itch demo
fox publish steam release main
```

`fox publish` uploads the bundles already sitting in `export/<env>/<target>/`.
It never talks to a store API itself: it drives the **official command line tool
of that store**, so the tool used depends on where the build goes.

| store | tool used | what it uploads | install |
|---|---|---|---|
| `steam` | `steamcmd` | one folder per **depot** | [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD) |
| `itch` | `butler` | one folder per **channel** | [butler](https://itch.io/docs/butler/installing.html) |

You only need the tool of the store you publish to: a project shipping to itch.io
alone never installs SteamCMD.

## steam, with steamcmd

SteamPipe uploads a build described by VDF scripts. Fox writes them for you in
`_build/steam/` from the depots declared in `fox.config.json`, then runs:

```sh
steamcmd +login <your-partner-login> +run_app_build _build/steam/app_build_<appId>.vdf +quit
```

The Steam Guard prompt reaches your terminal, so the first login of the day is
answered right there. When a branch is given, the build is set live on it; with
no branch, it stays unassigned and waits for you in Steamworks › SteamPipe ›
Builds.

### the macOS bundle is unfolded first

The macOS preset exports a `.zip` holding the `.app`, because that is the only
shape Godot can sign and notarize. A depot, however, ships what it is given: an
untouched folder puts a single archive in the depot, so the launch option
`<Game>.app` declared in Steamworks points at nothing, no macOS player can start
the game, and the checklist line *the default branch includes `<Game>.app`*
stays unticked whatever branch you set live.

So `fox publish steam` unfolds the archive in place before writing the VDF:
`unzip` restores the executable bit of the binary, and the archive is removed so
the depot never carries the same bundle twice. There is no archive left
afterwards, so running it again changes nothing. An archive holding no `.app` is
left alone.

## itch.io, with butler

itch.io has no depots: each folder is pushed to a **channel**, and the channel
name is what tells itch which platform it is (a name carrying `windows`, `linux`
or `osx`). Fox runs one push per declared channel:

```sh
butler push export/demo/itch/windows uralys/my-game:windows-demo --userversion 0.20.0
```

## before either one

Whatever the store, the same gate runs first: the version and env are read back
from the **bytes in the export folder**, not from `project.godot`, and shown for
confirmation. If they disagree, the first answer offered is the `fox export` that
would fix it.

Stores, credentials, depots and channels are declared in `fox.config.json`, and
are described in [env and target](./envs-and-targets.md).

Once a build is up, [`fox ls`](./ls.md) confronts what the stores carry with what
your export folder holds.
