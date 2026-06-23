# In-App Purchases (Stores)

Fox ships two autoloads wrapping the platform IAP plugins:

- `AppStore` — iOS, via the
  [InAppStore](https://github.com/godotengine/godot-ios-plugins/blob/master/plugins/inappstore/README.md)
  plugin
- `PlayStore` — Android, via the
  [godot-google-play-iapp](https://github.com/code-with-max/godot-google-play-iapp)
  plugin

Both expose the same surface: a `purchase(sku)` method and a
`skuDetailsReceived` signal, and both no-op gracefully when their native
singleton is absent (e.g. in the editor or on desktop).

## Setup

Add the relevant store(s) as autoloads:

```ini
[autoload]

AppStore="*res://fox/stores/appstore.gd"
PlayStore="*res://fox/stores/playstore.gd"
```

Both stores expect your game to provide:

- `G.STORE` — a dictionary keyed by SKU, each value an item you can decorate
  with the localized `price` once received (and `isConsumable` on Android);
- a `Player` autoload exposing `bought(sku)`, `previouslyBought(sku)`,
  `save()` and a `state` dictionary (Android uses `Player.state.purchasesToConsume`
  to back up tokens awaiting acknowledgement).

```gdscript
# G.STORE example
var STORE = {
  'com.your.game.coins_100': {isConsumable = true},
  'com.your.game.remove_ads': {isConsumable = false},
}
```

## Flow

On `_ready`, each store connects to its native singleton, fetches product info,
and on Android also queries past purchases (to recover purchases made outside the
app). When prices arrive, `skuDetailsReceived` fires so your shop UI can refresh.

```gdscript
func _ready():
  var store = AppStore if Bundle.getPlatform() == 'iOS' else PlayStore
  store.skuDetailsReceived.connect(_refreshPrices)

func buy(sku):
  var store = AppStore if Bundle.getPlatform() == 'iOS' else PlayStore
  store.purchase(sku)   # shows the loader, runs the native flow
```

`purchase()` calls `Router.showLoader()` and the store hides it again on
success / error / cancel. On success the store calls `Player.bought(sku)` (or
`Player.previouslyBought(sku)` when restoring a prior purchase at startup).

## Testing

- **iOS**: use
  [sandbox testers](https://appstoreconnect.apple.com/access/testers); switch the
  sandbox user from `Settings > App Store > Sandbox Account`.
- **Android**: use a license-tester account; purchases must be acknowledged
  (Fox does this automatically) and consumables consumed.
