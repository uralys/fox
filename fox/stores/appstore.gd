# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------
# plugin: https://github.com/godotengine/godot-ios-plugins/blob/master/plugins/inappstore/README.md
# ------------------------------------------------------------------------------
# sandbox test users: https://appstoreconnect.apple.com/access/testers
# connect/logout sandbox users: Reglages > AppStore > sandbox user
# ------------------------------------------------------------------------------

var appStore

# ------------------------------------------------------------------------------

signal skuDetailsReceived

# ------------------------------------------------------------------------------

func _ready():
  if Engine.has_singleton('InAppStore'):
    G.log('-------------------------------')
    G.log('✅ AppStore starting: InAppStore was found')
    appStore = Engine.get_singleton('InAppStore')
    fetchItems()

# ------------------------------------------------------------------------------

## looping here when there is a process, to wait for StoreKit results
func checkEvents():
  G.log('[AppStore] checking events...');
  if appStore.get_pending_event_count() > 0:
    var event = appStore.pop_pending_event()

    if event.result == 'ok':
      match event.type:
        'product_info':
          G.log({event=event});
          for i in event.ids.size():
            var sku = event.ids[i]
            var price = event.localized_prices[i]
            var item = G.STORE[sku]
            item.price = price

          emit_signal('skuDetailsReceived')

          return

        'purchase':
          var sku = event.product_id
          Router.hideLoader()
          Player.bought(sku)
          return

        # other possible values are 'progress', 'error', 'unhandled'
        _:
          G.log({event=event})

    # user cancelled or could not pay
    elif event.result == 'error':
      Router.hideLoader()
      return

  waitAWhileAndCheckEvents()

# ------------------------------------------------------------------------------

func purchase(sku):
  G.log('purchasing ', sku);
  Router.showLoader()
  appStore.purchase({product_id = sku})
  waitAWhileAndCheckEvents()

# ------------------------------------------------------------------------------

func fetchItems():
  var skus = G.STORE.keys()
  var result = appStore.request_product_info( { 'product_ids': skus } )
  if result == OK:
    appStore.set_auto_finish_transaction(true)
    waitAWhileAndCheckEvents()

  else:
    G.log('🔴 [AppStore] failed requesting product info')

# ------------------------------------------------------------------------------

func waitAWhileAndCheckEvents():
  await Wait.forSomeTime(self, 1).timeout
  checkEvents()
