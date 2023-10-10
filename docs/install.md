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

Create a `src` folder and Create a new scene with Godot Editor, you can name it `main.tscn`.

Then add attach a `main.gd` script to this scene.

You can remove the default code and replace with:

```gdscript
extends 'res://fox/core/main.gd'

func _ready():
  super._ready()
  print(G.BUNDLE_ID + ' is running!')
```

Finally, right click on your `main.tscn` to `Set as Main Scene`

Or edit manually your `project.godot` to declare:

```ini
[application]
run/main_scene="res://src/main.tscn"
```

### 4 - Declare Fox default config

Now you need to setup Fox default paths within the `project.godot` `[autoload]` section.

```ini
[autoload]

G="*res://fox/core/globals.gd"
DEBUG="*res://fox/core/debug.gd"
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

### 5 - Let's craft

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
      ├── main.gd
      └── main.tscn
```

You can have a look at your startup app:

```sh
fox run:start
```

and now let's start your editor and enjoy developing!

```sh
fox run:editor
```

### Note about the default splashscreen

Note: at this point you will have warnings about missing assets, you can either implement your own splahscreen, or copy the ones from `fox/assets/sprites/splash` to `your-game/assets/sprites/splash`, then refresh your editor to import them with Godot.

This behaviour is the default I share between my games and could be improved to a more generic splashscreen in the future.

## 🏹 extending default Fox Nodes

To extend a Fox default Node, you can do like with did with the main scene: Extend the Node from you script.

For exmaple, to extend Globals and add your own:

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
