# Popups

You can create Popups by creating a `ReferenceRect` extending `components/popup`:

```gd
extends 'res://fox/components/popup.gd'
```

if you override the `_ready` function, make sure to call `super._ready()`:

```gd
func _ready():
  super._ready()
```

then add a function somewhere to instantiate the popup, for example in your `Router`

```gd
var ShopPopup = preload('res://shop.tscn')

func openShop():
  var shop = ShopPopup.instantiate()
  $/root/app/popups.add_child(shop)
```

## Blur and Panel

- You can add a `components/blur.tscn`, name it `blur`, to blur the background, the popup will automatically show/hide the blur.

- You can add a `Panel`, name it `panel`, to automatically show/hide your content.

- Inside this panel, you can add a `closeButton` with a `pressed` signal to automatically call the `close` function.

example:

```gd
extends 'res://fox/components/popup.gd'

# ------------------------------------------------------------------------------

func _ready():
  super._ready()

  Animate.from(panel, {
    propertyPath = 'position',
    fromValue = panel.position + Vector2(0, G.H),
    duration = 1,
    transition= Tween.TRANS_QUAD,
    easing = Tween.EASE_OUT
  })

# ------------------------------------------------------------------------------

func close():
  Router.openHome()
```
