# 📦 Installing Fox

## prerequisites

| Tool | Needed by | Install |
|------|-----------|---------|
| Godot 4 | everything | [godotengine.org](https://godotengine.org/download) |
| NodeJS >= 26 | the `fox` CLI | [nodejs.org](https://nodejs.org) |
| ImageMagick 7 | every `fox generate:*` command | `brew install imagemagick` |
| iconutil | the macOS `.icns` desktop icon written by `fox generate:icons` | shipped with macOS, nothing to install |
| bundletool | inspecting Android `.aab` bundles, see [exporting/android](./exporting/android.md) | `brew install bundletool` |
| libimobiledevice | installing iOS builds on a device, see [exporting/ios](./exporting/ios.md) | `brew install libimobiledevice` |

ImageMagick 7 provides the `magick` binary. The deprecated `convert` shim is
never used: if `magick` is missing from your `PATH`, the `generate:*` commands
stop right away with a non-zero exit code instead of pretending to work.

`iconutil` is the only tool able to write a real `.icns`: ImageMagick silently
writes a PNG wearing an `.icns` extension. It ships with macOS, so nothing has
to be installed there. On Linux and Windows `fox generate:icons` **skips the
`.icns` output with a warning** and keeps going: the run stays green, and the
`icon.png` and `icon.ico` desktop icons are produced as usual. Only a macOS
export needs the `.icns`, and only macOS can build it.

## starting from scratch

### 1 - New Godot Project

Start by opening Godot Editor and create a new project with `Godot > New Project > Create folder >` `your-game`

Then > `Select Current Folder`

Edit your project settings and `Create & Edit`

### 2 - Install Fox

One command, run **from your project folder**, on macOS, Linux and Windows (Git
Bash or WSL):

```sh
cd your-game
curl -fsSL https://raw.githubusercontent.com/uralys/fox/main/install.sh | sh
```

That is the whole install. It reads the latest release and installs both halves
of Fox from its git tag, so they can never come from two different versions:

- the **runtime**, mounted at `addons/fox` in the project you ran it from. It is
  a plain Godot addon, and it is what your game actually runs on. It is a
  **dependency, not game code**: the installer adds it to your `.gitignore` and
  writes the version it installed into `fox.config.json`, as `core.fox`;
- the **`fox` executable**, installed globally with npm.

A version can be forced, and a project named rather than entered:

```sh
curl -fsSL https://raw.githubusercontent.com/uralys/fox/main/install.sh | sh -s -- 2.2.0
curl -fsSL https://raw.githubusercontent.com/uralys/fox/main/install.sh | sh -s -- your-game
```

Run outside a Godot project, it installs the CLI alone and says so: `fox upgrade`
mounts the runtime later, from inside the game.

#### the mount is ignored, and `core.fox` remembers the version

`addons/fox` is replaced whole on every upgrade, and swapped for a symlink by
`fox link`: a game tracking it reads the first as a wall of changes nobody wrote,
and the second as its entire runtime deleted. So the installer ignores it, and
records the version in the config your game already commits:

```json
{
  "core": {
    "fox": "2.3.0"
  }
}
```

That pin is what makes a clone reproducible: run from a project holding **no**
mount, the installer restores the version `core.fox` names rather than the
latest release. A clone of your game is therefore two commands, like any project
with dependencies:

```sh
git clone your-game && cd your-game
curl -fsSL https://raw.githubusercontent.com/uralys/fox/main/install.sh | sh
```

A game that used to commit its mount has one step to take, once, since git
ignores nothing it already follows:

```sh
git rm -r --cached addons/fox
```

See [pinning a version](./cli/versioning.md) for the whole of it.

#### NodeJS is a prerequisite of the CLI, not of Fox

The runtime needs nothing but Godot. A machine without NodeJS is therefore not a
failed install: the addon is mounted all the same, and the CLI is skipped with a
warning. Everything in this page still applies, minus the `fox` commands.

#### upgrading afterwards

The installer is for the first time. From then on, one command moves both halves
at once:

```sh
fox upgrade          # pin the latest release
fox upgrade 2.0.0    # or the version you want
```

Both rewrite `core.fox` with the version they pin, so the commit that moves Fox
carries one readable line rather than a few hundred. Both also **delete**
`addons/fox` before laying the next version down, so a file dropped between two
versions leaves with it. Writing over the
folder instead, by hand or through the Godot Asset Library, piles up the
leftovers forever. See [pinning a version](./cli/versioning.md).

#### 🦊 working on Fox itself: the linked mount

Contributors who develop **Fox** mount their checkout at `res://addons/fox`
instead of pinning a copy, so the game rides their working tree:

```sh
cd your-game
fox link ../fox
```

A mount that is already such a symlink is left alone by the installer: it never
replaces a checkout with a pinned copy. The whole contributor setup (checkout,
running the CLI from it, the WSL junction, lint) lives in
[contributing](./contributing.md). A game consuming a released Fox never needs
it.

### 3 - Declare your main Scene

#### create the main script

Create a `src` folder and Create a new scene with Godot Editor, you can name it `app.tscn`.

Then add attach a `app.gd` script to this scene.

You can remove the default code and replace with:

```gdscript
extends 'res://addons/fox/core/app.gd'

func _ready():
  super._ready()
  print(G.BUNDLE_ID + ' is running!')
```

Note: `super._ready()` is mandatory: it sets up the Fox core nodes and settings
(screen reference, debug flags, notifications).

#### set as main scene

Finally, right click on your `app.tscn` to `Set as Main Scene`

Or edit manually your `project.godot` to declare:

```ini
[application]
run/main_scene="res://src/app.tscn"
```

#### create mandatory nodes

You must setup a few nodes in your main scene:

by default:

- `app` should be a `CanvasLayer`
- `app/scene` should also be a `Node2D`
- `app/hud` should be a `CanvasLayer`

To change these defaults, edit the `addons/fox/core` "extends XXX"

```sh
app
├── scene
└── hud
```

### 4 - Enable the Fox plugin

Fox registers its own autoloads through an `EditorPlugin`. Open the editor and
enable it once:

`Project > Project Settings > Plugins > Fox > Enable`

Enabling the plugin writes these autoloads into your `project.godot`:

| Autoload | Script |
|----------|--------|
| `G` | `res://addons/fox/core/globals.gd` |
| `DEBUG` | `res://addons/fox/core/debug.gd` |
| `Gesture` | `res://addons/fox/autoloads/gesture.gd` |

An autoload your game already declares is **left untouched**: the plugin skips
any `autoload/<Name>` already present in the project settings, so an override
(see [extending default Fox Nodes](#-extending-default-fox-nodes)) always wins,
whatever the order in which you enable the plugin.

#### optional autoloads

The other libs are autoloads too, and the plugin does not register them: add
the ones you use to the `[autoload]` section of your `project.godot`.

```ini
[autoload]

Controls="*res://addons/fox/autoloads/controls.gd"
HotReload="*res://addons/fox/autoloads/hot-reload.gd"
Generate="*res://addons/fox/autoloads/generate.gd"
FrameProbe="*res://addons/fox/autoloads/frame-probe.gd"
Sound="*res://addons/fox/core/sound.gd"
Leaderboard="*res://addons/fox/core/leaderboard.gd"
AppStore="*res://addons/fox/iap/appstore.gd"
PlayStore="*res://addons/fox/iap/playstore.gd"
```

See each lib's doc for what it brings and how to configure it.

#### bundle options

Finally, set your bundle defaults:

```ini
[bundle]

id="your-game"
version="0.0.1"
versionCode=1
platform="xxx"
env="debug"
```

### Let's craft!

At this point, you should have something like this:

```sh
your-game
├──.godot
├── addons
│   └── fox
├── fox.config.json
├── icon.svg
├── project.godot
└── src
    ├── app.gd
    └── app.tscn
```

You can have a look at your startup app:

```sh
fox run:game
```

and now let's start your editor and enjoy developing!

```sh
fox run:editor
```

## 🏹 extending default Fox Nodes

To extend a Fox default Node, you can do like with did with the main scene: Extend the Node from you script.

For example, to extend Globals and add your own:

Create a `globals.gd`

```gdscript
extends 'res://addons/fox/core/globals.gd'
```

And replace the autoload in `project.godot` with yours:

```ini
[autoload]
G="*res://src/globals.gd"
```

Since the plugin skips any autoload already declared, this override survives a
disable / enable cycle of the Fox plugin.

To better use Fox core, screens and components, you can organise your project like this:

```sh
.
├── fox
└── your-game
  ├── assets
  │   ├── map.png
  │   └── logo.svg
  ├── addons
  │   └── fox -> ../../fox/addons/fox
  ├── fox.config.json
  ├── project.godot
  ├── readme.md
  └── src
      ├── main.gd
      ├── main.tscn
      ├── player.gd
      ├── router.gd
      └── screens
          ├── home.tscn
          └── home.gd
```

🚀 You can continue by extending the [Router](./gdscript/router.md) to add your first screens.
