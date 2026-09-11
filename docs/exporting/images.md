# 🖼️ Images generation for release

- create a `_release/images` folder
- add a `.gdignore` file to `_release`

## where the generated assets land

Three commands write into `assets/generated/`, and they all share the same
layout: **one folder per bundle, one folder per platform**. An export preset
reads its own folder and excludes every other one, so an iOS build no longer
carries the Windows icons of a bundle it knows nothing about.

```txt
assets/generated/
├── boot-splash.png                 1920x1080, logo 920 px (project wide)
└── <bundleId>/
    ├── ios/
    │   ├── icon-40x40.png … icon-1024x1024.png   (40, 58, 60, 76, 80, 87,
    │   │                                          120, 152, 167, 180, 1024)
    │   ├── splash@2x.png           1170x2532
    │   └── splash@3x.png           1290x2796
    ├── android/
    │   ├── icon-192x192.png
    │   ├── adaptive-background.png
    │   └── adaptive-foreground.png
    ├── desktop/
    │   ├── icon.png                512x512
    │   ├── icon.ico                256, 128, 64, 48, 32, 16 in one file
    │   └── icon.icns               macOS only, see below
    └── web/
        ├── pwa-144x144.png
        ├── pwa-180x180.png
        └── pwa-512x512.png
```

`<bundleId>` comes from the `bundles` section of your `fox.config.json`. A
project without that section gets a single `default/` folder: same layout, so
the presets never need a special case.

The whole folder is generated, therefore disposable: it belongs in your
`.gitignore`, and any of these commands rebuilds it from `_release/images/`.

All five `generate:*` commands need **ImageMagick 7**, see
[prerequisites](../install.md#prerequisites).

## Icons

use `addons/fox/assets/android/adaptive_icon_template.afdesign` at your convenience, to generate these files:

- android adaptive: use `adaptive` artboard, hide parts for foreground/background, export 1000x1000
- icon 1200x1200: use `ios` artboard
- icon 512x512: use `ios` artboard
- icon desktop 512x512: use `desktop` artboard

export using

```sh
fox generate:icons
```

It loops over every bundle and produces, from your base image, only the sizes an
export preset actually reads. The seven sizes no build ever consumed (20, 29,
32, 64, 128, 256, 512) are not written anymore.

```json
"generate:icons": {
  "input": "_release/images/",
  "output": "assets/generated",
  "base": "icon-1200x1200.png",
  "desktop": "icon-desktop-512x512.png",
  "background": "adaptive-background.png",
  "foreground": "adaptive-foreground.png"
}
```

### iOS

`fox export` fills these paths itself, on every export. They are listed here so
you can recognise them in `export_presets.cfg`, with `<bundleId>` being the
bundle of that preset:

```ini
icons/iphone_120x120="res://assets/generated/<bundleId>/ios/icon-120x120.png"
icons/iphone_180x180="res://assets/generated/<bundleId>/ios/icon-180x180.png"
icons/ipad_76x76="res://assets/generated/<bundleId>/ios/icon-76x76.png"
icons/ipad_152x152="res://assets/generated/<bundleId>/ios/icon-152x152.png"
icons/ipad_167x167="res://assets/generated/<bundleId>/ios/icon-167x167.png"
icons/app_store_1024x1024="res://assets/generated/<bundleId>/ios/icon-1024x1024.png"
icons/spotlight_40x40="res://assets/generated/<bundleId>/ios/icon-40x40.png"
icons/spotlight_80x80="res://assets/generated/<bundleId>/ios/icon-80x80.png"
icons/settings_58x58="res://assets/generated/<bundleId>/ios/icon-58x58.png"
icons/settings_87x87="res://assets/generated/<bundleId>/ios/icon-87x87.png"
icons/notification_40x40="res://assets/generated/<bundleId>/ios/icon-40x40.png"
icons/notification_60x60="res://assets/generated/<bundleId>/ios/icon-60x60.png"
```

### android

```ini
launcher_icons/main_192x192="res://assets/generated/<bundleId>/android/icon-192x192.png"
launcher_icons/adaptive_foreground_432x432="res://assets/generated/<bundleId>/android/adaptive-foreground.png"
launcher_icons/adaptive_background_432x432="res://assets/generated/<bundleId>/android/adaptive-background.png"
```

more info for android: <https://github.com/godotengine/godot-docs/blob/master/tutorials/export/exporting_for_android.rst#providing-launcher-icons>

### desktop

`application/icon` takes the format of its platform, and the Windows console
wrapper always takes the `.ico`:

```ini
application/icon="res://assets/generated/<bundleId>/desktop/icon.icns"  # macOS
application/icon="res://assets/generated/<bundleId>/desktop/icon.ico"   # windows
application/icon="res://assets/generated/<bundleId>/desktop/icon.png"   # linux
application/console_wrapper_icon="res://assets/generated/<bundleId>/desktop/icon.ico"
```

`icon.ico` is a genuine multi-resolution icon (six frames in one file) and
`icon.icns` is built by `iconutil`, which only exists on macOS. On Linux and
Windows the `.icns` is **skipped with a warning**, never treated as a failure.
See [prerequisites](../install.md#prerequisites).

## Splashscreens

- generate a `_release/images/base-splashscreen.png` and extends its dimension using

```sh
fox generate:splashscreens
```

iOS dropped the launch images: a build now ships a **launch screen storyboard**,
which needs two images instead of eleven. The command writes them per bundle,
next to the iOS icons:

```json
"generate:splashscreens": {
  "input": "_release/images/base-splashscreen.png",
  "output": "assets/generated",
  "backgroundColor": "#181818"
}
```

The base image is centered on a `backgroundColor` canvas extended to the target
size. `fox export` points the preset at the result and empties the legacy
`landscape_launch_screens/*` and `portrait_launch_screens/*` slots, so you never
have to type these three keys:

```ini
storyboard/use_launch_screen_storyboard=true
storyboard/custom_image@2x="res://assets/generated/<bundleId>/ios/splash@2x.png"
storyboard/custom_image@3x="res://assets/generated/<bundleId>/ios/splash@3x.png"
```

## Boot splash

The boot splash is the very first image Godot paints, before a single script
runs (`application/boot_splash/image` in `project.godot`). It is project wide,
not per bundle, and lands in `assets/generated/boot-splash.png`.

```sh
fox generate:boot-splash
```

```json
"generate:boot-splash": {
  "input": "res://addons/fox/assets/splash/logo-uralys.png",
  "output": "assets/generated/boot-splash.png",
  "backgroundColor": "#000000"
}
```

```ini
application/boot_splash/image="res://assets/generated/boot-splash.png"
```

The geometry is **not** configurable, on purpose: the boot splash, the animated
splash screen and the iOS launch storyboard must show the same logo at the same
size, so the canvas and the logo width are read from `BASE_CANVAS` and
`LOGO_BASE_WIDTH` in `addons/fox/components/splash/splash-screen.gd`. Change the
constant there, run the command again, and the three surfaces stay aligned.

Keep `backgroundColor` equal to your `boot_splash/bg_color`, or a seam shows
when the boot splash hands over to the animated one.

## Screenshots

Take screenshots from your app, then use this command to generate all resized resolutions:

```sh
fox generate:screenshots
```

Default orientation is `landscape`, if you need `portrait` add this in your `fox.config.json`:

```json
"generate:screenshots": {
  "orientation": "portrait"
}
```

## what the export excludes on its own

The generated part of every `exclude_filter` belongs to fox. On each
`fox export`, the preset being exported gets the foreign generated folders
listed for it: the other platforms of its own bundle, then the other bundles
whole.

```ini
exclude_filter="*.md,assets/generated/lockey-land/ios/*,assets/generated/lockey-land/desktop/*,assets/generated/lockey-land/web/*,assets/generated/chapter1/*"
```

Three things follow:

- the filters you wrote yourself are **preserved**: only the tokens starting
  with `assets/generated/` are rewritten, everything else is left alone;
- the rewrite is **idempotent**: exporting twice gives the same filter, filters
  never pile up;
- stop maintaining these lines by hand. Removing your handwritten
  `assets/generated/...` tokens is safe, fox writes them back.

The same pass fixes the icon and storyboard slots of the preset, and an export
whose declared `res://assets/generated/...` file is missing is **refused**, with
the name of the file and the `fox generate:*` command to run.

## migrating a game from the flat folder

Projects created before this layout keep a flat `assets/generated/icons/`. Five
steps, and no preset edited by hand:

1. in your `fox.config.json`, point both `generate:icons.output` and
   `generate:splashscreens.output` at the shared root `assets/generated` (a
   legacy icons `output` ending in `/icons` is normalised anyway);
2. declare `bundles` if the game ships several, so each one gets its folder;
3. run `fox generate:icons`, `fox generate:splashscreens` and
   `fox generate:boot-splash`;
4. run `fox export` once per preset: the icon slots, the storyboard slots and
   the `exclude_filter` are rewritten to the new convention;
5. delete the leftover flat `assets/generated/icons/` and
   `assets/generated/splashscreens/` folders.

A preset hand written long ago may still declare an iOS slot for one of the
seven abandoned sizes (20, 29, 32, 64, 128, 256, 512). Nothing generates those
any more, so the export preflight refuses the build until the slot is cleared:
empty it in `export_presets.cfg`. A stock Godot 4 preset never carries one.
