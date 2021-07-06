# Godot extension

## install

To keep same paths and `res://`, symlink like this:

```sh
> ln -s ../godox/extension extension
```

## prepare core elements

### Main

create a Main scene, attach `main.gd`

```gdscript
extends 'res://extension/core/main.gd'
```

Default start screen is `Home`, you can override `startScreen()`

```gdscript
extends 'res://extension/core/main.gd'

func startScreen():
  Router.openYourCustomScreen()
```

### Playground

create a `src/screens/playground.gd`

```gdscript
extends 'res://extension/screens/playground.gd'

func onOpen():
  .onOpen()
```

### Router

create a `src/core/router.gd`

```gdscript
extends 'res://extension/core/router.gd'
```

and add it as `Autoload`

## run

watch files and restart `Godot` using:

```sh
> node extension/scripts/run.js
```
