# ------------------------------------------------------------------------------

extends CanvasLayer

# ------------------------------------------------------------------------------

var SplashAnimation = preload('res://fox/animations/splash-animation.tscn')
var NotificationsScheduler = preload('res://fox/behaviours/notifications.tscn')

# ------------------------------------------------------------------------------

# your app must call super._ready() to initialize the game using:
# ```func _ready():
#      super._ready()
#      loadApp()
# ```
func _ready():
  DEBUG.setup()
  createScreenReference()
  prepareNotifications()
  randomize() # https://docs.godotengine.org/en/latest/tutorials/math/random_number_generation.html#the-randomize-method

# ------------------------------------------------------------------------------

func startSplashAnimation():
  if(DEBUG.NO_SPLASH_ANIMATION):
    return

  var splash = SplashAnimation.instantiate()
  add_child(splash)

  # may await splash.splashFinished
  return splash

# ------------------------------------------------------------------------------

func createScreenReference():
  var screenReference = ReferenceRect.new()
  screenReference.name = 'screenReference'

  screenReference.position = Vector2(0, 0)
  screenReference.mouse_filter = Control.MOUSE_FILTER_IGNORE
  screenReference.anchors_preset = Control.PRESET_FULL_RECT
  screenReference.anchor_right = Control.PRESET_FULL_RECT
  screenReference.anchor_right = 1.0
  screenReference.anchor_bottom = 1.0
  screenReference.grow_horizontal = Control.GROW_DIRECTION_BOTH
  screenReference.grow_vertical = Control.GROW_DIRECTION_BOTH

  $hud.add_child(screenReference)
  recordScreenDimensions()
  $/root.connect('size_changed', recordScreenDimensions)

func recordScreenDimensions():
  var screenReference = $/root/app/hud/screenReference
  G.W = screenReference.get_rect().size.x
  G.H = screenReference.get_rect().size.y
  G.SCREEN_CENTER = Vector2(G.W /2.0, G.H /2.0)

# ------------------------------------------------------------------------------

var scheduler

func prepareNotifications():
  var useNotifications = ProjectSettings.get_setting('custom/useNotifications')
  if(not useNotifications):
    return

  scheduler = NotificationsScheduler.instantiate()
  $/root.add_child.call_deferred(scheduler)

  call_deferred('_configureScheduler')

# ------------------------------------------------------------------------------

func _configureScheduler():
  var h = scheduler.has_post_notifications_permission()
  G.log('has_post_notifications_permission:', h);

  var chanId = 'CHAN_BATTLE_ID'
  scheduler.create_notification_channel(chanId, "My Channel Name", "My channel description")

  var my_notification_data = NotificationData.new()
  my_notification_data.set_id(1)\
    .set_channel_id(chanId)\
    .set_title("Youhou!")\
    .set_content("Time to gift")\
    .set_small_icon_name("notification_icon")

  # G.log('scheduling', {my_notification_data=my_notification_data} );
  # scheduler.schedule(my_notification_data, 3)
