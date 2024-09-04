# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------
# Android - Google Play Store
# ------------------------------------------------------------------------------
# plugin: https://github.com/code-with-max/godot-google-play-iapp
# response codes: https://developer.android.com/reference/com/android/billingclient/api/BillingClient.BillingResponseCode
# ------------------------------------------------------------------------------

var playStore
var queryingPurchasesAtStart = false
var purchasesToConsume = {}

# ------------------------------------------------------------------------------

signal skuDetailsReceived

# ------------------------------------------------------------------------------

func _ready():
  if Engine.has_singleton('AndroidIAPP'):
    G.log('-------------------------------')
    G.log('✅ AndroidIAPP was found, connecting PlayStore.')
    playStore = Engine.get_singleton('AndroidIAPP')
    connectPlayStore()

# ------------------------------------------------------------------------------

func connectPlayStore():
  # https://github.com/code-with-max/godot-google-play-iapp?tab=readme-ov-file#information-signals
  playStore.connect('connected', playStoreConnected)

  # https://github.com/code-with-max/godot-google-play-iapp?tab=readme-ov-file#billing-signals
  playStore.connect('query_purchases', receivedPurchases)
  playStore.connect('purchase_updated', onPurchasesUpdated)
  playStore.connect('purchase_error', onPurchaseError)
  playStore.connect('purchase_update_error', onPurchaseError)
  playStore.connect('purchase_cancelled', onPurchaseCancelled)

  playStore.connect('query_product_details', receivedProductDetails)
  playStore.connect('query_product_details_error', failedQueryingProductDetails)
  playStore.connect('purchase_acknowledged', onPurchaseAcknowledged)
  playStore.connect('purchase_acknowledged_error', onPurchaseAcknowledgementError)
  playStore.connect('purchase_consumed', onPurchaseDone)
  playStore.connect('purchase_consumed_error', onPurchaseConsumptionError)

  playStore.startConnection()

# ==============================================================================

func playStoreConnected():
  queryingPurchasesAtStart = true

  # Handling purchases made outside your app
  # https://developer.android.com/google/play/billing/integrate#ooap
  playStore.queryPurchases('inapp') # Use 'subs' for subscriptions.

  # Show products available to buy
  # https://developer.android.com/google/play/billing/integrate#show-products
  for sku in G.STORE:
    playStore.queryProductDetails([sku], 'inapp')

# ==============================================================================

# response: https://github.com/code-with-max/godot-google-play-iapp/blob/be71531d191ad2a4989ba8658e40bee2f3367790/AndroidIAPP/src/main/java/one/allme/plugin/androidiapp/AndroidIAPP.kt#L262
func receivedProductDetails(response):
  for receivedItem in response.product_details_list:
    G.log('receivedItem', receivedItem);
    var sku = receivedItem.product_id
    var item = G.STORE[sku]
    # https://github.com/code-with-max/godot-google-play-iapp/blob/be71531d191ad2a4989ba8658e40bee2f3367790/AndroidIAPP/src/main/java/one/allme/plugin/androidiapp/utils/IAPP_utils.kt#L93
    item.price = receivedItem.one_time_purchase_offer_details.formatted_price

  skuDetailsReceived.emit()

# ------------------------------------------------------------------------------

# response: https://github.com/code-with-max/godot-google-play-iapp/blob/be71531d191ad2a4989ba8658e40bee2f3367790/AndroidIAPP/src/main/java/one/allme/plugin/androidiapp/AndroidIAPP.kt#L268
func failedQueryingProductDetails(response):
  G.log(
    '🔴 PlayStore: error querying product details:',
     ' message: ', response.debug_message,
  )
  G.log('Do you use the correct tester account?');

# ==============================================================================

# response: https://github.com/code-with-max/godot-google-play-iapp/blob/be71531d191ad2a4989ba8658e40bee2f3367790/AndroidIAPP/src/main/java/one/allme/plugin/androidiapp/AndroidIAPP.kt#L211
func receivedPurchases(response):
  G.log('✅ PlayStore: received ' + str(response.purchases_list.size()) +  ' purchases')

  if response.response_code == OK:
    for _purchase in response.purchases_list:
      # We must acknowledge all purchases.
      # See https://developer.android.com/google/play/billing/integrate#process for more information
      var sku =  _purchase.products[0]

      if not _purchase.is_acknowledged:
        G.log('Purchase ' + str(sku) + ' has not been acknowledged. Acknowledging...')
        playStore.acknowledgePurchase(_purchase.purchase_token)

      # _purchase is_acknowledged but not consumed => either not consumed or not consumable
      elif _purchase.purchase_state == 1:
        storePurchaseToken(_purchase.purchase_token, sku)
        onPurchaseAcknowledged({purchase_token = _purchase.purchase_token})

  else:
    G.log('🔴 PlayStore: queryPurchases failed, response code: ',
      response.response_code,
      ' debug message: ',
      __.Get('debug_message', response)
    )

# ==============================================================================

func purchase(sku):
  G.log('purchasing ', sku);
  Router.showLoader()
  playStore.purchase([sku], false)

# ------------------------------------------------------------------------------

# response: https://github.com/code-with-max/godot-google-play-iapp/blob/be71531d191ad2a4989ba8658e40bee2f3367790/AndroidIAPP/src/main/java/one/allme/plugin/androidiapp/AndroidIAPP.kt#L443
func onPurchaseCancelled(_response):
  Router.hideLoader()

# ------------------------------------------------------------------------------

# codes: https://developer.android.com/reference/com/android/billingclient/api/BillingClient.BillingResponseCode
# response: https://github.com/code-with-max/godot-google-play-iapp/blob/be71531d191ad2a4989ba8658e40bee2f3367790/AndroidIAPP/src/main/java/one/allme/plugin/androidiapp/AndroidIAPP.kt#L337
func onPurchaseError(response):
  Router.hideLoader()
  var code = response.response_code
  var debug_message = response.debug_message
  match(code):
    3:
      G.log('> paiement refused.')
      return
    7:
      G.log('> player already owns this sku')
      return
    _:
      G.log('🔴 Error during purchase', {
        id = __.Get('product_id', response),
        message = debug_message
      })

# ------------------------------------------------------------------------------

# https://developer.android.com/reference/com/android/billingclient/api/PurchasesUpdatedListener
# listener for purchases updates / initiated by a buy action from the game or the Play Store
# kind of the successfull callback for purchase()
# response: https://github.com/code-with-max/godot-google-play-iapp/blob/be71531d191ad2a4989ba8658e40bee2f3367790/AndroidIAPP/src/main/java/one/allme/plugin/androidiapp/AndroidIAPP.kt#L438
func onPurchasesUpdated(response):
  for _purchase in response.purchases_list:
    var sku = JSON.parse_string(_purchase.original_json).productId
    var purchaseToken = _purchase.purchase_token
    storePurchaseToken(purchaseToken, sku)

  queryingPurchasesAtStart = false
  playStore.queryPurchases('inapp')

# ==============================================================================

# response: https://github.com/code-with-max/godot-google-play-iapp/blob/be71531d191ad2a4989ba8658e40bee2f3367790/AndroidIAPP/src/main/java/one/allme/plugin/androidiapp/AndroidIAPP.kt#L540
func onPurchaseConsumptionError(response):
  Router.hideLoader()
  G.log('🔴 Error during consumption', {
    message = response.debug_message,
    purchaseToken = response.purchase_token
  })

# ==============================================================================

# response: https://github.com/code-with-max/godot-google-play-iapp/blob/be71531d191ad2a4989ba8658e40bee2f3367790/AndroidIAPP/src/main/java/one/allme/plugin/androidiapp/AndroidIAPP.kt#L535
func onPurchaseDone(response):
  var purchaseToken = response.purchase_token
  Router.hideLoader()

  if(queryingPurchasesAtStart):
    foundPreviousPurchase(purchaseToken)
  else:
    onPurchaseCompleted(purchaseToken)

# ==============================================================================
# android purchases backup waiting to be acknowleged
# ==============================================================================

func storePurchaseToken(purchaseToken, sku):
  if(!__.Get('purchasesToConsume', Player.state)):
    Player.state.purchasesToConsume = {}

  Player.state.purchasesToConsume[purchaseToken] = sku
  Player.save()

func _getSKUFromPurchaseToken(purchaseToken):
  var sku = Player.state.purchasesToConsume[purchaseToken]
  return sku

func _eraseTokenSincePurchaseHasBeenConsumed(purchaseToken):
  Player.state.purchasesToConsume.erase(purchaseToken)
  Player.save()

# ---------------

func onPurchaseCompleted(purchaseToken):
  var sku = _getSKUFromPurchaseToken(purchaseToken)
  Player.bought(sku)
  _eraseTokenSincePurchaseHasBeenConsumed(purchaseToken)

# ---------------

func foundPreviousPurchase(purchaseToken):
  var sku = _getSKUFromPurchaseToken(purchaseToken)
  Player.previouslyBought(sku)
  _eraseTokenSincePurchaseHasBeenConsumed(purchaseToken)

# ------------------------------------------------------------------------------

# response: https://github.com/code-with-max/godot-google-play-iapp/blob/be71531d191ad2a4989ba8658e40bee2f3367790/AndroidIAPP/src/main/java/one/allme/plugin/androidiapp/AndroidIAPP.kt#L560
func onPurchaseAcknowledged(response):
  var purchaseToken = response.purchase_token
  var sku = _getSKUFromPurchaseToken(purchaseToken)
  var storeItem = G.STORE[sku]

  if(__.GetOr(false, 'isConsumable', storeItem)):
    G.log('consuming', sku);
    playStore.consumePurchase(purchaseToken)
  else:
    onPurchaseDone({purchase_token = purchaseToken})

# ---------------

# response: https://github.com/code-with-max/godot-google-play-iapp/blob/be71531d191ad2a4989ba8658e40bee2f3367790/AndroidIAPP/src/main/java/one/allme/plugin/androidiapp/AndroidIAPP.kt#L565
func onPurchaseAcknowledgementError(response):
  Router.hideLoader()
  G.log('🔴 Purchase acknowledgement error:', {
    message = response.debug_message,
    purchaseToken = response.purchase_token
  })
