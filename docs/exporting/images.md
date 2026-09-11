# Images generation for release

- create a `_release/images` folder
- add a `.gdignore` file to `_release`

Everything below is written under `assets/generated/`, one folder per bundle and
per platform. The layout, the config keys and the migration from the old flat
folder are described in [the CLI doc](../cli.md#generated-assets).

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

`icon.icns` is only built on macOS: it needs `iconutil`, see
[prerequisites](../install.md#prerequisites).

## Splashscreens

- generate a `_release/images/base-splashscreen.png` and extends its dimension using

```sh
fox generate:splashscreens
```

iOS reads a launch screen storyboard, so two images replace the eleven legacy
launch screens. `fox export` points the preset at them and empties the legacy
`landscape_launch_screens/*` and `portrait_launch_screens/*` slots:

```ini
storyboard/use_launch_screen_storyboard=true
storyboard/custom_image@2x="res://assets/generated/<bundleId>/ios/splash@2x.png"
storyboard/custom_image@3x="res://assets/generated/<bundleId>/ios/splash@3x.png"
```

## Boot splash

The frame Godot paints before any script runs, shared by every bundle:

```sh
fox generate:boot-splash
```

```ini
application/boot_splash/image="res://assets/generated/boot-splash.png"
```

Its geometry comes from `addons/fox/components/splash/splash-screen.gd`, so the boot
splash, the animated splash and the iOS storyboard always show the same logo at
the same size.

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
