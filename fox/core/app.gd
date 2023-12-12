extends Node

func _ready():
  prints('========================================')
  var foxVersion = ProjectSettings.get_setting('fox/version')
  foxVersion = foxVersion if foxVersion else ''
  prints('[🦊 Fox]', foxVersion)
  prints('-------------------------------')
  prints('viewport:', get_viewport().size)
  prints('window:', get_window().get_size())
  prints('-------------------------------')

  G.BUNDLE_ID = ProjectSettings.get_setting('bundle/id')
  G.ENV = ProjectSettings.get_setting('bundle/env')
  G.PLATFORM = ProjectSettings.get_setting('bundle/platform')
  G.VERSION = ProjectSettings.get_setting('bundle/version')
  G.VERSION_CODE = ProjectSettings.get_setting('bundle/versionCode')

  G.RECORD_PATH = 'user://saved-data.' + G.BUNDLE_ID + '.bin'

  prints('bundle/id: ' + G.BUNDLE_ID)
  prints('bundle/env: ' + G.ENV)
  prints('bundle/platform: ' + G.PLATFORM)

  checkEnv()

  prints('========================================')

  createScreenReference()

  randomize() # https://docs.godotengine.org/en/latest/tutorials/math/random_number_generation.html#the-randomize-method

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
