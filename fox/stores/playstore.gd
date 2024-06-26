# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------
# Android - Google Play Store
# ------------------------------------------------------------------------------
# reference: https://docs.godotengine.org/en/stable/tutorials/platform/android/android_in_app_purchases.html
# plugin: https://github.com/godotengine/godot-google-play-billing
# demo: https://github.com/godotengine/godot-demo-projects/blob/master/mobile/android_iap/iap_demo.gd
# ------------------------------------------------------------------------------

var playStore
var queryingPurchasesAtStart = false
var purchasesToConsume = {}

# ------------------------------------------------------------------------------

signal skuDetailsReceived

# ------------------------------------------------------------------------------

func _ready():
  if Engine.has_singleton('GodotGooglePlayBilling'):
    G.log('-------------------------------')
    G.log('✅ GodotGooglePlayBilling was found, connecting PlayStore.')
    playStore = Engine.get_singleton('GodotGooglePlayBilling')
    connectPlayStore()

# ------------------------------------------------------------------------------

func connectPlayStore():
  playStore.connect('connected', playStoreConnected) # No params
  # playStore.connect('disconnected', _on_disconnected) # No params
  playStore.connect('connect_error', playStoreErrorOnConnection) # Response ID (int), Debug message (string)
  playStore.connect('query_purchases_response', receivedPurchases) # Purchases (Dictionary[])
  playStore.connect('purchases_updated', onPurchasesUpdated) # Purchases (Dictionary[])
  playStore.connect('purchase_error', onPurchaseError) # Response ID (int), Debug message (string)
  playStore.connect('sku_details_query_completed', receivedSKUDetails) # SKUs (Dictionary[])
  playStore.connect('sku_details_query_error', failedQueryingSKUDetails) # Response ID (int), Debug message (string), Queried SKUs (string[])
  playStore.connect('purchase_acknowledged', onPurchaseAcknowledged) # Purchase token (string)
  playStore.connect('purchase_acknowledgement_error', onPurchaseAcknowledgementError) # Response ID (int), Debug message (string), Purchase token (string)
  playStore.connect('purchase_consumed', onPurchaseDone) # Purchase token (string)
  playStore.connect('purchase_consumption_error', onPurchaseConsumptionError) # Response ID (int), Debug message (string), Purchase token (string)

  playStore.startConnection()

# ==============================================================================

func playStoreConnected():
  queryingPurchasesAtStart = true
  playStore.queryPurchases('inapp') # Use 'subs' for subscriptions.

  for sku in G.STORE:
    playStore.querySkuDetails([sku], 'inapp')

# ------------------------------------------------------------------------------

func playStoreErrorOnConnection(id, message):
  G.log('🔴 PlayStore: Error on connection', id, message)

# ==============================================================================

# details: [{ "icon_url": "", "original_price": "0,99 €", "original_price_amount_micros": 990000, "introductory_price_period": "", "description": "blabla", "title": "blaplop", "type": "inapp", "price_amount_micros": 990000, "price_currency_code": "EUR", "introductory_price_cycles": 0, "introductory_price": "", "introductory_price_amount_micros": 0, "price": "0,99 €", "free_trial_period": "", "subscription_period": "", "sku": "xxx.xxx.xxx" }]
func receivedSKUDetails(details):
  for receivedItem in details:
    var item = G.STORE[receivedItem.sku]
    item.price = receivedItem.price

  emit_signal('skuDetailsReceived')

# ------------------------------------------------------------------------------

func failedQueryingSKUDetails(response_id, error_message, products_queried):
  G.log(
    '🔴 PlayStore: error querying SKU details:', response_id,
     ' message: ', error_message,
     " products: ", products_queried
  )
  G.log('Do you use the correct tester account?');

# ==============================================================================

func receivedPurchases(query_result):
  G.log('✅ PlayStore: received ' + str(query_result.purchases.size()) +  ' purchases')

  if query_result.status == OK:
    for _purchase in query_result.purchases:
      # We must acknowledge all purchases.
      # See https://developer.android.com/google/play/billing/integrate#process for more information

      if not _purchase.is_acknowledged:
        G.log('Purchase ' + str(_purchase.skus[0]) + ' has not been acknowledged. Acknowledging...')
        playStore.acknowledgePurchase(_purchase.purchase_token)

      # _purchase is_acknowledged but not consumed => either not consumed or not consumable
      elif _purchase.purchase_state == 1:
        storePurchaseToken(_purchase.purchase_token, _purchase.sku)
        onPurchaseAcknowledged(_purchase.purchase_token)

  else:
    G.log('🔴 PlayStore: queryPurchases failed, response code: ',
      query_result.response_code,
      ' debug message: ',
      query_result.debug_message
    )

# ==============================================================================

func purchase(sku):
  G.log('purchasing ', sku);
  Router.showLoader()
  var response = playStore.purchase(sku)
  if response.status != OK:
    G.log('🔴 Purchase could not be sent: error %s: %s' % [
      response.response_code,
      response.debug_message
    ])

# ------------------------------------------------------------------------------

# codes: https://developer.android.com/reference/com/android/billingclient/api/BillingClient.BillingResponseCode
func onPurchaseError(id, message):
  Router.hideLoader()
  match(id):
    1:
      G.log('> player cancelled')
      return
    3:
      G.log('> paiement refused.')
      return
    7:
      G.log('> player already owns this sku')
      return
    _:
      G.log('🔴 Error during purchase', {id=id, message=message})

# ------------------------------------------------------------------------------

# https://developer.android.com/reference/com/android/billingclient/api/PurchasesUpdatedListener
# listener for purchases updates / initiated by a buy action from the game or the Play Store
# kind of the successfull callback for purchase()
func onPurchasesUpdated(purchases):
  for _purchase in purchases:
    var sku = JSON.parse_string(_purchase.original_json).productId
    var purchaseToken = _purchase.purchase_token
    storePurchaseToken(purchaseToken, sku)

  queryingPurchasesAtStart = false
  playStore.queryPurchases('inapp')

# ==============================================================================

func onPurchaseConsumptionError(id, message, purchaseToken):
  Router.hideLoader()
  G.log('🔴 Error during consumption', {
    id = id,
    message = message,
    purchaseToken = purchaseToken
  })

# ==============================================================================

func onPurchaseDone(purchaseToken):
  Router.hideLoader()

  if(queryingPurchasesAtStart):
    foundPreviousPurchase(purchaseToken)
  else:
    onPurchaseCompleted(purchaseToken)

# ==============================================================================
# android purchases backup waiting to be acknowleged
# ==============================================================================

func storePurchaseToken(purchaseToken, sku):
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

func onPurchaseAcknowledged(purchaseToken):
  var sku = _getSKUFromPurchaseToken(purchaseToken)
  var storeItem = G.STORE[sku]

  if(__.GetOr(false, 'isConsumable', storeItem)):
    G.log('consuming', sku);
    playStore.consumePurchase(purchaseToken)
  else:
    onPurchaseDone(purchaseToken)

# ---------------

func onPurchaseAcknowledgementError(id, message, purchaseToken):
  Router.hideLoader()
  G.log('🔴 Purchase acknowledgement error:', {
    id = id,
    message = message,
    purchaseToken = purchaseToken
  })
