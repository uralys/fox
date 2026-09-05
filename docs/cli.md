# 🔋 experimental NodeJS CLI

- to watch your files and allow to `live reload` your game.
- to `export` your debug and release bundles.
- to `generate` your release icons and screenshots.

<img title="exporting-illustration" height="270px"  src="../assets/docs/cli-export.png"/>

## requirements

To use the CLI you'll need NodeJS installed

### prepare the executable

Install the dev dependencies from the fox folder:

```sh
cd path/to/fox
npm install
```

link the `fox` executable:

macOS:

```sh
ln -s ~/Projects/uralys/gamedev/fox/cli/cli.js /usr/local/bin/fox
```

WSL/Linux:

```sh
sudo ln -s /home/user/Projects/uralys/gamedev/fox/cli/cli.js /usr/local/bin/fox
```

Windows (PowerShell):

Add a function to your PowerShell profile (`$PROFILE`):

```powershell
function fox { node "C:\Users\chris\Projects\uralys\gamedev\fox\cli\cli.js" @args }
```

You may have to reload your terminal to have `fox` in your path;

You can now execute fox commands from your terminal:

```sh
fox
```

You can pass parameters to Godot by using them directly from the command line.

See all available parameters on [Godot CLI Reference](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html#command-line-reference)

Example:

```sh
fox run:game --headless --debug-collisions
```

## usage

```ini
Usage: fox <command> [options]

Commands:
  fox run:editor                open Godot Editor with your main scene

  fox run:game                  start your game locally (watch + hot reload)

  fox import [--force]          import assets headless, as the editor does
                                when opening the project

  fox tag [patch|minor|major]   bump version in project.godot and create a
                                git tag

  fox export                    export a bundle for one of your presets

  fox publish [store] [env]     upload exported builds to a store
                 [branch]       (steamcmd for steam, butler for itch)

  fox switch                    switch from a bundle to another (writes
                                override.cfg)

  fox ls                        list the local exports and the builds
                                installed on the Steam Deck, and compare them

  fox generate:icons            generate icons, using a base 1200x1200 image

  fox generate:splashscreens    generate splashscreens, extending a background
                                color from a centered base image

  fox generate:screenshots      resize store screenshots to the required sizes

  fox generate:steam-screenshots  resize screenshots for the Steam store

  fox update-po-files           run msgmerge on the project .po translation
                                files (experimental)
```

- more details for exporting [here](./exporting/export.md)
- the two axes a build is made of, `env` and `target`, are described [here](./exporting/envs-and-targets.md)

## ls

`fox ls` answers one question: **is the build installed on the Steam Deck the one sitting in my export folder?**

Neither half can answer it alone. Steam knows a `BuildID` and a branch, but nothing about what those bytes contain; the export folder knows a version, but not whether Steam ever shipped it. So both are read and confronted on the **PCK** — the payload itself, identical across platforms unlike the executable.

Every Steam app declared under `publish.steam.envs` in `fox.config.json` is listed, so a project shipping a demo next to the game gets both.

```sh
fox ls
```

```txt
●  Fox v1.14.4 ls
├─ Faraday Corridors — project.godot is 0.20.0
●  Local demo — appId 4873710 — export/demo/
│  ┌──────────────────────────────────────────────────────────────────┐
│  │ windows: 0.20.0 DEMO — exported 2026-09-03 19:25 645fd7567aba    │
│  │ linux: 0.20.0 DEMO — exported 2026-09-03 19:25 f33d253d3199      │
│  │ macos: faraday-corridors-demo.zip — archive not read             │
│  │ steam deck: build 25107059 on "staging" — 0.20.0 DEMO f33d253d3199 │
│  └──────────────────────────────────────────────────────────────────┘
├─ ✓  demo: the deck runs the exact export/demo/linux payload (0.20.0)
```

The version and env printed for each depot are read from the **bytes on disk**, never from `project.godot`: an export left on another env is exactly the accident this listing exists to show.

### what it warns about

- the depots disagree on the version, or the export is behind `project.godot`
- the branch **requested** differs from the branch **mounted** (Steam needs a restart)
- `buildid` differs from `TargetBuildID` — an update is pending on the Deck
- the Deck PCK is not the local `linux` one, with both short sha256 shown

### the Steam Deck is optional

It is a listing, never a gate: an unreachable Deck prints one info line and the local half is reported on its own.

```txt
●  SteamDeck deck@steamdeck.local not connected — local builds only (…)
```

The host defaults to `deck@steamdeck.local` over `ssh` in batch mode. Override it per project:

```json
{
  "ls": {
    "host": "deck@steamdeck.local",
    "timeout": 8
  }
}
```

## import

```sh
fox import           # incremental: only outdated assets
fox import --force   # wipes .godot/imported, reimports everything
```

`fox import` runs `godot --headless --path . --import`, which boots the editor
without its window: same `EditorFileSystem` scan as opening the project
(autoloads, enabled editor plugins, `EditorScenePostImport` scripts, per-file
`.import` settings), then quits once the import is done.

It is **incremental**, exactly like the editor: an asset whose source and import
settings did not change is not reimported. `--force` deletes the
`.godot/imported` cache first, so everything is rebuilt — the `.import` files
are never touched, your import settings are preserved.

Being headless, there is no `RenderingDevice`: GPU texture compression falls
back to the CPU compressor (slower, same format) and no filesystem thumbnails
are generated. Godot returns `0` even when an importer logs an error, so read
the output rather than trusting the exit code.

Useful before any headless run (tests, screenshots, export) or after a batch of
assets landed on disk, to avoid opening the editor just for that.

## hot reload

`fox run:game` watches your project files (`.gd`, `.tscn`, `.cfg`, `.json`, `.yml`) and hot reloads the current scene when a change is detected.

Instead of killing and restarting the Godot process, it writes a `.hot-reload` trigger file. The `HotReload` autoload inside Godot detects this file and calls `Router.reloadCurrentScene()`, which re-instantiates the current scene without closing the window.

### Setup

Add `HotReload` to your project's `[autoload]` section in `project.godot`:

```ini
[autoload]

HotReload="*res://fox/libs/hot-reload.gd"
```

Add `.hot-reload` and `.nav-state` to your `.gitignore`.

### Ignoring folders

`.worktrees/` and `.godot/` are always ignored. To skip additional folders (tooling, generated data, sub-projects), list them in `run:game.ignored` of your `fox.config.json`:

```json
{
  "run:game": {
    "ignored": ["solutions"]
  }
}
```

### Navigation state (NavState)

The Router persists a typed `NavState` (`fox/core/nav-state.gd`) to `.nav-state` (JSON). It stores the current scene path and a `path` array representing nested sub-view segments — similar to outlets in Ember.js or React Router.

On hot reload or full restart (`r`), the app restores the last visited scene and navigates to the exact sub-view.

**NavState JSON example:**

```json
{"scene_path":"res://src/screens/storybook.tscn","path":["Focal Blur"]}
```

**Router API:**

- `Router.getNavPath() -> Array` — read the current path segments
- `Router.setNavPath(path: Array)` — update and persist the path
- `Router.restoreOrDefault(defaultAction: Callable)` — restore nav state on startup, or call default

**Scene pattern — each scene reads/writes its own path segments:**

```gdscript
func onOpen(options = {}):
    var navPath = Router.getNavPath()
    if not navPath.is_empty():
        selectedEntry = navPath[0]        # restore from navPath
    else:
        selectedEntry = __.GetOr('default', 'entry', options)  # normal nav
    Router.setNavPath([selectedEntry])

func _onSubViewSelected(name: String):
    Router.setNavPath([selectedEntry, name])  # nested sub-view
```

**Startup (main.gd) — use `restoreOrDefault` in debug mode:**

```gdscript
func run():
    Router.restoreOrDefault(func(): Router.openHome())
```

### Limitations

In standalone mode, GDScript files are compiled on load. Hot reload works well for data changes (JSON, resources) and `.tscn` scenes. For `.gd` script changes, the scene is re-instantiated but scripts in memory may not update — use `r` for a full restart in that case.

## shortcuts

- `r` — full restart (kills and relaunches Godot, useful when hot reload is not enough)
- `ctrl + c` — stop the game
