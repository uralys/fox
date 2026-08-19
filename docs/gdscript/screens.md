# Screens & responsive layout

Fox provides two base classes that auto-refresh their layout when the window is
resized, so you get responsive UI (Steam Deck ↔ desktop) with zero per-screen
glue:

- `FoxScreen` — for router scenes (Node2D-rooted)
- `FoxScreen3D` — for router scenes (Node3D-rooted)
- `FoxPopup` — for popups / overlays (Control-rooted)

Both delegate the resize wiring to `ViewportResize`, a single source of truth.

## FoxScreen

Base class for game screens opened by the [Router](./router.md). Extend it and
override `_onViewportResized()` to rebuild your responsive layout:

```gdscript
extends FoxScreen

func _ready():
  _layout()

func _onViewportResized() -> void:
  _layout()

func _layout() -> void:
  # recompute positions / scales for the current screen size
  pass
```

The viewport `size_changed` signal is connected automatically in `_enter_tree`
and disconnected in `_exit_tree` — you never call `super()` from `_ready`.

## FoxScreen3D

Same contract as `FoxScreen`, for router scenes whose root is a `Node3D` instead
of a `Node2D` (3D gameplay screens). Extend it and override `_onViewportResized()`
just like the 2D base:

```gdscript
extends FoxScreen3D

func _ready():
  _layout()

func _onViewportResized() -> void:
  _layout()
```

The resize wiring is identical (delegated to `ViewportResize` in `_enter_tree` /
`_exit_tree`), so the router needs no per-scene duck-typing to refresh 3D screens
on resize.

## FoxPopup

Same contract for popups / overlays added under `$/root/app/popups` (rather than
being the router's current scene):

```gdscript
extends FoxPopup

func _onViewportResized() -> void:
  _layout()
```

> A subclass that overrides `_exit_tree` must call `super._exit_tree()` so the
> resize signal is properly disconnected.

## ViewportResize

`ViewportResize` is the shared wiring used by both bases — you rarely touch it
directly. It exposes two idempotent statics:

- `ViewportResize.attach(node, handler)` — connect `node`'s viewport
  `size_changed` to `handler` (if not already connected)
- `ViewportResize.detach(node, handler)` — disconnect it (if connected)

Use it only if you need resize refresh on a node that cannot extend a Fox base.

## Responsive helper

`FoxResponsive` (`core/responsive.gd`) holds the shared responsive maths. It is
engine-agnostic on purpose: GDScript statics do not dispatch virtually, so the
base can never read a game-specific token or autoload — each game passes its
width threshold (`min_desktop_width`) and its "this is a handheld" hook
(`force_compact`, e.g. `SteamManager.is_steam_deck()`) at the call site, usually
through a thin project-side `Responsive` wrapper.

### The rule: one global scale factor

The mechanism a Fox game should use is a **single global scale factor**, posed
once on the window at boot and re-posed on every resize:

```gdscript
# src/main.gd
func _ready():
	super._ready()
	Responsive.apply_content_scale(get_window())  # BEFORE anything is laid out
	load_app()
	get_viewport().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized():
	Responsive.apply_content_scale(get_window())
```

`apply_content_scale` writes `Window.content_scale_factor`: `1.0` on desktop, the
game's handheld factor otherwise (faraday-corridors: `1.5`, so a 1920-wide base
canvas lands on the Deck's 1280 physical pixels — 1 logical unit = 1 physical
pixel). The factor **composes** with the project stretch (`canvas_items` +
`expand`), so the whole canvas is re-rendered at the screen resolution: text and
hairlines are **re-rasterised**, not upscaled.

Why it matters: with that factor in place, **a screen has nothing responsive to
do**. Every widget is written once, at its native size, in logical coordinates.
No per-component multiplier, no per-screen derogation.

Two rules survive the global factor:

- **The verdict is taken on the PHYSICAL window size**
  (`FoxResponsive.screen_size()`, i.e. `DisplayServer.window_get_size()`), never
  on `get_viewport_rect().size`. This trap gets *more* dangerous once the factor
  is in place: logical ≈ physical at the nominal resolutions, so a viewport-based
  test appears to work and only breaks on an unusual window shape or a docked
  handheld.
- **A frame is never scaled, only its content is.** A `node.scale` still resamples
  whatever it carries — border included. Size the frame (`size = base * fit`) and
  let a child `content` node carry the fit.

Note (2026-08-19) — known divergence: `FoxResponsive` still exposes the previous
model's API (a per-component multiplier, and a 7-parameter `fit_scale` with a
handheld margin). faraday-corridors no longer uses it: its `src/ui/responsive.gd`
is standalone, exposes exactly eight members (`is_desktop`, `screen_size`,
`is_portrait`, `content_scale`, `apply_content_scale`, `contain_fit`, `fit_scale`
at 3 parameters, `apply_cursor_visibility`) and implements the global factor
above. sylvestrine still runs on the older model; when it moves over, the
per-component helpers here can be dropped and `content_scale` /
`apply_content_scale` lifted into `FoxResponsive` with the factor injected like
`min_desktop_width` already is.
