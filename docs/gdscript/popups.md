# Popups

Fox has two popup helpers — pick the one that matches your need:

- **`components/popup.gd`** — the full-featured popup base: a `ReferenceRect`
  with automatic blur, a panel show/hide animation, and a close button. Use it
  for in-game dialogs (shop, confirm, review…). Documented below.
- **`FoxPopup`** (`core/popup.gd`) — a minimal `Control` base that only adds
  responsive refresh (`_onViewportResized`) on window resize. Use it for custom
  overlays that manage their own visuals. See [screens & responsive](./screens.md#foxpopup).

## Creating a popup

Create a `ReferenceRect` extending `components/popup`:

```gdscript
extends 'res://fox/components/popup.gd'
```

If you override `_ready`, call `super._ready()`:

```gdscript
func _ready():
  super._ready()
```

Instantiate it somewhere, typically in your `Router`, adding it under the
`popups` node:

```gdscript
var ShopPopup = preload('res://shop.tscn')

func openShop():
  var shop = ShopPopup.instantiate()
  $/root/app/popups.add_child(shop)
```

## Blur, panel and close button

The base wires up child nodes by name automatically:

- a `components/blur.tscn` named `blur` → blurred background, shown/hidden with
  the popup;
- a `Panel` named `panel` → its content is faded in/out automatically;
- a `closeButton` (inside the panel) with a `pressed` signal → calls `close()`
  automatically.

Exports / flags:

- `blurAmount: int = 60` — target blur strength
- `thisPopupPauseEngine` — set `true` to pause the tree while the popup is open
- `closed` signal — emitted on close

## Example

```gdscript
extends 'res://fox/components/popup.gd'

func _ready():
  super._ready()

  Animate.from(panel, {
    propertyPath = 'position',
    fromValue = panel.position + Vector2(0, G.H),
    duration = 1,
    transition = Tween.TRANS_QUAD,
    easing = Tween.EASE_OUT
  })

func close():
  Router.openHome()
```
