# Fox

[![License](https://img.shields.io/badge/License-MIT-green.svg?colorB=3cc712)](license) [![version](https://img.shields.io/github/package-json/v/uralys/fox)](https://github.com/uralys/fox/tags)

🦊 Fox provides tooling while developing with Godot Engine.

<p align="center"><img title="fox"  src="./assets/logo.jpg"></p>

## Scenes and scripts

With Fox, you can use `Scenes`, `Resources`, scripts and static functions to build your app.

As an example, this code will move 3 nodes to the same position, with a delay of 1 second between each animation. Finally it fill print 'DONE' in the console.

```gdscript
  Animate.to([potion, car, book], {
    propertyPath = "position",
    toValue = Vector2(0, 0),
    delayBetweenElements = 1,
    onFinished = func():
      G.log('DONE');
  })
```

## Documentation

Few documentation links (find more in the [docs](./docs)):

- [Installing](./docs/install.md) Fox to use in your Godot app

Coding:

- Using the [Router](./docs/gdscript/router.md)
- Using [Animation](./docs/gdscript/animations.md) Tween helpers
- Using `Touchable` and `Draggable` Nodes with an [interactiveArea2D](./docs/gdscript/interactive-area-2d.md) behaviour on any Node
- Using [DraggableCamera](./docs/gdscript/draggable-camera.md)
- Using [Sound](./docs/gdscript/sound.md)
- static functions inspired by [Underscore](/fox/libs/underscore.gd)

Exporting:

- [Installing the CLI](./docs/cli.md)
- Info about [Android](./docs/exporting/android.md) settings and building
- Info about [iOS](./docs/exporting/ios.md) settings and building

## Games created with Fox

<a href="https://uralys.com/avindi"><img alt="logo" width="128" title="avindi" src="./assets/docs/games/avindi-desktop-512x512.png"/></a>
<a href="https://apps.apple.com/us/app/battle-squares/id1609783397"><img alt="logo" width="128" title="battle-squares" src="./assets/docs/games/battle-squares-desktop-512x512.png"/>
<a href="https://uralys.com/lockeyland"><img alt="logo" width="128" title="lockey0" src="./assets/docs/games/lockey0-desktop-512x512.png"></a>
<a href="https://uralys.com/lockeyland"><img alt="logo" width="128" title="lockey1" src="./assets/docs/games/lockey1-desktop-512x512.png"></a>
