# 🦊 Fox

Godot extension to share between apps.

## install

To keep same paths and `res://`, symlink like this:

```sh
> ln -s ../fox/fox fox
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

### Playground

create a `src/screens/playground.gd`

```gdscript
extends 'res://fox/screens/playground.gd'

func onOpen():
  # --> anything you need to setup
  .onOpen() # --> then call fox.playground.onOpen()
```

### Router

create a `src/core/router.gd`

```gdscript
extends 'res://fox/core/router.gd'
```

and add it as `Autoload`

## run

watch files and restart `Godot` using:

```sh
> node fox/scripts/run.js
```
