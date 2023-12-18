# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

var SplashAnimation = preload('res://fox/animations/splash-animation.tscn')

# ------------------------------------------------------------------------------

func finalizeFoxSetup():
  DEBUG.printEnabledOptions()
  prints('------------------------')
  checkEnv()
  createScreenReference()
  randomize() # https://docs.godotengine.org/en/latest/tutorials/math/random_number_generation.html#the-randomize-method
  prints('------------------------')

# ------------------------------------------------------------------------------

func checkEnv():
  if(G.ENV != 'release'):
    prints('⚠️👾 ENV='+G.ENV)

  for cliOptions in OS.get_cmdline_args():
    if(cliOptions == 'local-fox-runner'):
      G.IS_FOX_RUNNER = true

  if(G.ENV == G.RELEASE and G.IS_FOX_RUNNER):
    prints('⚠️👾 Started with Fox and release settings.')

# ------------------------------------------------------------------------------

func startSplashAnimation():
  if(DEBUG.NO_SPLASH_ANIMATION):
    return

  var splash = SplashAnimation.instantiate()
  add_child(splash)

  await splash.splashFinished

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
