# Images generation for release

- create a `_release/images` folder
- add a `.gdignore` file to `_release`

## Icons

use `fox/assets/android/adaptive_icon_template.afdesign` at your convenience, to generate these files:

- android adaptive: use `adaptive` artboard, hide parts for foreground/background, export 1000x1000
- icon 1200x1200: use `ios` artboard
- icon 512x512: use `ios` artboard
- icon desktop 512x512: use `desktop` artboard

export using

```sh
fox generate:icons
```

once exported you can fill the paths in the iOS export section:

```ini
icons/iphone_120x120="res://assets/generated/icons/icon-120x120.png"
icons/iphone_180x180="res://assets/generated/icons/icon-180x180.png"
icons/ipad_76x76="res://assets/generated/icons/icon-76x76.png"
icons/ipad_152x152="res://assets/generated/icons/icon-152x152.png"
icons/ipad_167x167="res://assets/generated/icons/icon-167x167.png"
icons/app_store_1024x1024="res://assets/generated/icons/icon-1024x1024.png"
icons/spotlight_40x40="res://assets/generated/icons/icon-40x40.png"
icons/spotlight_80x80="res://assets/generated/icons/icon-80x80.png"
icons/settings_58x58="res://assets/generated/icons/icon-58x58.png"
icons/settings_87x87="res://assets/generated/icons/icon-87x87.png"
icons/notification_40x40="res://assets/generated/icons/icon-40x40.png"
icons/notification_60x60="res://assets/generated/icons/icon-60x60.png"
```

## Splashscreens

- generate a `_release/images/base-splashscreen.png` and extends its dimension using

```sh
fox generate:splashscreens
```

once it's done you can fill the paths in the iOS export section:

```ini
landscape_launch_screens/iphone_2436x1125="res://assets/generated/splashscreens/splashscreen-2436x1125.png"
landscape_launch_screens/iphone_2208x1242="res://assets/generated/splashscreens/splashscreen-2208x1242.png"
landscape_launch_screens/ipad_1024x768="res://assets/generated/splashscreens/splashscreen-1024x768.png"
landscape_launch_screens/ipad_2048x1536="res://assets/generated/splashscreens/splashscreen-2048x1536.png"
portrait_launch_screens/iphone_640x960="res://assets/generated/splashscreens/splashscreen-640x960.png"
portrait_launch_screens/iphone_640x1136="res://assets/generated/splashscreens/splashscreen-640x1136.png"
portrait_launch_screens/iphone_750x1334="res://assets/generated/splashscreens/splashscreen-750x1334.png"
portrait_launch_screens/iphone_1125x2436="res://assets/generated/splashscreens/splashscreen-1125x2436.png"
portrait_launch_screens/ipad_768x1024="res://assets/generated/splashscreens/splashscreen-768x1024.png"
portrait_launch_screens/ipad_1536x2048="res://assets/generated/splashscreens/splashscreen-1536x2048.png"
portrait_launch_screens/iphone_1242x2208="res://assets/generated/splashscreens/splashscreen-1242x2208.png"
```
