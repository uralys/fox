# Godot extension

## install

To keep same paths and `res://`, symlink like this:

```sh
> ln -s ../godox/extension extension
```

## use core elements

- Main

```gdscript
extends 'res://extension/core/main.gd'

func _ready():
  ._ready()
```

- Router

```gdscript
extends 'res://extension/core/router.gd'
```

- Playground

```gdscript
extends 'res://extension/screens/playground.gd'

func onOpen():
  .onOpen()
```
