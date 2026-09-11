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

### 2 - Mount Fox as an addon

Fox is a standard Godot addon: its runtime tree lives in `addons/fox` of this
repository, and your game mounts it at `res://addons/fox`.

Copy the addon folder at the version you want, and commit it with your game:

```sh
git clone --depth 1 --branch v2.0.1 https://github.com/uralys/fox /tmp/fox-2.0.1
mkdir -p your-game/addons
cp -R /tmp/fox-2.0.1/addons/fox your-game/addons/fox
```

Your game is now pinned: nothing outside `addons/fox` belongs to Fox, so moving
to the next version is a matter of deleting that folder and copying the next one
in. Once the [CLI](./cli.md) is installed, one command does it for you:

```sh
fox upgrade          # pin the latest release
fox upgrade 2.0.0    # or the version you want
```

#### 🦊 working on Fox itself: the linked mount

> This section is for contributors who develop **Fox**, and open pull requests
> on this repository. A game consuming a released Fox never needs it: a linked
> game rides the working tree of the fox checkout, so the version its
> `plugin.cfg` declares is whatever that checkout happens to hold rather than a
> released one. It is deliberately unsuited to shipping.

Clone this repo next to `your-game`:

```sh
git clone https://github.com/uralys/fox
```

Then link the addon folder into your game, so `res://addons/fox` always reflects
your local fox checkout:

**macOS / Linux:**

```sh
cd your-game
fox link ../fox     # or, without the CLI:
ln -s ../../fox/addons/fox addons/fox
```

The `ln -s` target is relative to the `addons` folder holding it, hence the two
`..` levels.

**Windows / WSL:**

On WSL, `ln -s` creates a Linux symlink that Godot (running as a native Windows app) cannot resolve. You must use a Windows NTFS junction instead:

```sh
cmd.exe /c "mklink /J C:\path\to\your-game\addons\fox C:\path\to\fox\addons\fox"
```

> **Note:** To use [check-projects](https://github.com/uralys/check-projects) on WSL, symlink your `/mnt/c/` repos into your Linux home:
>
> ```sh
> ln -s /mnt/c/Users/chris/Projects/uralys/gamedev/fox ~/Projects/uralys/gamedev/fox
> ln -s /mnt/c/Users/chris/Projects/uralys/gamedev/your-game ~/Projects/uralys/gamedev/your-game
> ```

Going back to a released version is `fox upgrade`, which replaces the link with
a real folder.

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

🚀 You can continue by extending the [Router](./router.md) to add your first screens.
