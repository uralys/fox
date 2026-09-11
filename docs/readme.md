# 📚 Fox documentation

Start with [Installing Fox](./install.md), then pick what you need below.

## Core

- [Globals & Debug](./gdscript/globals.md): `G` (globals + logging) and `DEBUG`
  (flags)
- [Router](./gdscript/router.md): scenes, transitions, nav state, overlays
- [Screens & responsive](./gdscript/screens.md): `FoxScreen`, `FoxPopup`,
  `ViewportResize`, `FoxResponsive` (the desktop / handheld split and the single
  global content scale factor)
- [Sound](./gdscript/sound.md): SFX, music, ducking
- [Files](./gdscript/files.md): bundle config + rotating save backups
  (cloud-safe)
- [Steam](./gdscript/steam.md): init, Steam Deck detection, achievements,
  floating keyboard, store overlay
- [Leaderboard](./gdscript/leaderboard.md): online boards, offline-first score
  queue, name claims

## Input

- [Controls](./gdscript/controls.md): unified keyboard / gamepad / stick input
- [interactiveArea2D](./gdscript/interactive-area-2d.md): touch, drag & drop on
  any Node
- [Multitouch Area](./gdscript/multitouch.md): press / drag listener
- [Draggable Camera](./gdscript/draggable-camera.md)

## Animation & UI

- [Animations](./gdscript/animations.md): `Animate` Tween helpers + `Framer`
- [Motion](./gdscript/motion.md): procedural idle motion (float, wobble,
  breathe)
- [Popups](./gdscript/popups.md)
- [Components](./gdscript/components.md): loader, screen fader, blur

## Libs & utilities

- [HTTP](./gdscript/http.md): REST client
- [Utility libs](./gdscript/utils.md): `__` (Underscore), `Wait`, `TimeTools`,
  `Bundle`, `Generate`, `HoloDrawUtils`, `MenuNavigator`, `ConfigStore`
- [Frame probe](./gdscript/frame-probe.md): frame-time instrument, off by
  default, grepable `[perf]` lines
- [In-app purchases](./gdscript/iap.md): iOS / Android stores

## Tooling & exporting

- [CLI](./cli.md): run, hot reload, export, publish
- [Building](./exporting/build.md) and [Exporting](./exporting/export.md)
- [Envs and targets](./exporting/envs-and-targets.md): the two axes a build is
  made of
- [Images generation](./exporting/images.md): icons, splashscreens, screenshots
- [Android](./exporting/android.md) and [iOS](./exporting/ios.md) settings

## Tips

- [Gamedev](./tips/gamedev.md)
- [Branding](./tips/branding.md)
