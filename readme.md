# 🦊 Fox [![License](https://img.shields.io/badge/License-MIT-green.svg?colorB=3cc712)](license) [![GitHub release](https://img.shields.io/github/release/uralys/fox.svg)](https://github.com/uralys/fox/releases)

Fox provides many tools to help develop with Godot Engine

- Godot components and libs to use directly in your game.
- a NodeJS CLI to:
  - watch your files and allow to live reload your game.
  - to build your debug and production bundles.
  - to generate your release icons and screenshots.

## Install

clone this repo next to your game folders

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

To keep same paths and `res://`, symlink godot elements in the `/fox` folder like this:

```sh
cd /path/to/your-game
ln -s ../fox/fox fox
```

## CLI

```sh
Usage: fox <command> [options]

Commands:
  fox generate:icons          generate icons, using a base 1200x1200 image
  fox generate:splashscreens  generate splashscreens, extending a background
                              color from a centered base image
  fox generate:screenshots    resize all images in a folder to 2560x1600, to
                              match store requirements
  fox run:editor              open Godot Editor
  fox run:game                start your game to debug
```

## Godot elements

You can use any elements from the `/fox` folder symlinked in your game:

- a router to move between your screens
- sounds (`Sound.play`)
- animations (`Animate.show`, `Animate.to` ...)
- static libs (`Wait`, `__.Get`, `__.Set`...)

you'll find documentation [here](./docs/godot-elements.md)
