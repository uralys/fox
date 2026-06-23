# Screens & responsive layout

Fox provides two base classes that auto-refresh their layout when the window is
resized, so you get responsive UI (Steam Deck ↔ desktop) with zero per-screen
glue:

- `FoxScreen` — for router scenes (Node2D-rooted)
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

The breakpoint logic (compact / desktop decision, fit & scale maths) lives in a
project-side `Responsive` helper, not in Fox core. The key rule: take the
**compact vs desktop** decision on the *physical* window size
(`DisplayServer.window_get_size()`), but compute the fit / scale on the *logical*
viewport size. With `stretch/mode = canvas_items`, `get_viewport_rect().size` is
the logical canvas size on every device (including the Steam Deck), so comparing
it to the breakpoint would misclassify the Deck as desktop.
