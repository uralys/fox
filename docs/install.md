# 📦 Installing Fox

## starting from scratch

### 1 - New Godot Project

Start by opening Godot Editor and create a new project with `Godot > New Project > Create folder >` `your-game`

Then > `Select Current Folder`

Edit your project settings and `Create & Edit`

### 2 - Clone this repo next to `your-game`

```sh
git clone https://github.com/uralys/fox
```

To keep same paths and `res://`, symlink godot elements in the `/fox` folder like this:

```sh
cd your-game
ln -s ../fox/fox fox
```

### 3 - Add fox.config.json

Create a file `fox.config.json` a your project's root

Leave it as an empty object for now, just know you can fill it to override the [default configuration](./fox/default.config.json):

```json
{}
```

### 4 - Declare your main Scene

#### create the main script

Create a `src` folder and Create a new scene with Godot Editor, you can name it `app.tscn`.

Then add attach a `app.gd` script to this scene.

You can remove the default code and replace with:

```gdscript
extends 'res://fox/core/app.gd'

func _ready():
  finalizeFoxSetup()
  print(G.BUNDLE_ID + ' is running!')
```

Note: `finalizeFoxSetup()` is mandatory to setup Fox core nodes and settings.

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

To change these defaults, edit the `fox/core` "extends XXX"

```sh
app
├── scene
└── hud
```

### 4 - Declare Fox default config

Now you need to setup Fox default paths within the `project.godot` `[autoload]` section.

```ini
[autoload]

G="*res://fox/core/globals.gd"
DEBUG="*res://fox/core/debug.gd"
Gesture="*res://fox/libs/gesture.gd"
```

and set few default options

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
.
├── fox
└── your-game
  ├──.godot
  ├── fox -> ../fox/fox
  ├── fox.config.json
  ├── icon.svg
  ├── project.godot
  └── src
      ├── app.gd
      └── app.tscn
```

You can have a look at your startup app:

```sh
fox run:start
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
extends 'res://fox/core/main.gd'
```

And replace the autoload in `project.godot` with yours:

```ini
[autoload]
G="*res://src/globals.gd"
```

To better use Fox core, screens and components, you can organise your project like this:

```sh
.
├── fox
└── your-game
  ├── assets
  │   ├── map.png
  │   └── logo.svg
  ├── fox -> ../fox/fox
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
