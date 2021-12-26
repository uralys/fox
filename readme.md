# 🦊 Fox

Fox provides many tools to help develop with Godot Engine

- Godot components and libs to use directly in your game.
- a NodeJS CLI to:
  - watch your files and allow to live reload your game.
  - to build your debug and production bundles.
  - to generate your release icons and screenshots.

## Install

clone this repo next to your games folders

```sh
git clone https://github.com/uralys/fox
```

```sh
└── your-gamedev
  ├── fox
  ├── your-game1
  └── your-game2
```

Install the dev dependencies

```sh
npm install
```

To use the CLI, link the `fox` executable:

```sh
npm link
```

You can now execute fox commands from your terminal

```sh
fox

🦊 Fox CLI vx.x.x
Documentation: https://github.com/uralys/fox
```

To keep same paths and `res://`, symlink like this:

```sh
cd /path/to/your-game
ln -s ../fox/fox fox
```

## prepare core elements

### Main

create a Main scene, attach `main.gd`

```gdscript
extends 'res://fox/core/main.gd'
```

Default start screen is `Home`, you can override `startScreen()`

```gdscript
extends 'res://fox/core/main.gd'

func startScreen():
  Router.openYourCustomScreen()
```

### Router

create a `src/core/router.gd`

```gdscript
extends 'res://fox/core/router.gd'
```

and add it as `Autoload`

## run

Watch files and restart your game `Godot` using:

```sh
> node fox/scripts/run-game.js
```

Open and sync your `Godot Editor` using:

```sh
> ./fox/scripts/run-editor.sh
```

### Sound

This core feature adds an `AudioStreamPlayer`

#### setup

create a `src/core/sound.gd`

```gdscript
extends 'res://fox/core/sound.gd'
```

and add it as `Autoload`

then you can implement the `play` like this:

```gdscript
var OGG = {
  onButtonPress = "res://path/to/your-sound.ogg",
  music = "res://path/to/your-music.ogg",
}

func play(soundName):
  var assetPath =__.Get(soundName, OGG)
  if(assetPath):
    .play(assetPath)
```

#### usage

Now you can call `Sound.play('music')` anywhere

#### note on loop behaviour

`.ogg` files will loop by default.

- Select them on the `FileSystem`,
- go to the `Import` tab next to the `Scene` tab
- unselect `loop`
- click on `Reimport`

#### default sound list

- `onButtonPress`
