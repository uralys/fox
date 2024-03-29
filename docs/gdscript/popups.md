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
