extends Node

var SplashAnimation = preload('res://fox/animations/splash-animation.tscn')

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

  randomize() # https://docs.godotengine.org/en/latest/tutorials/math/random_number_generation.html#the-randomize-method
  startSplashAnimation()

# ------------------------------------------------------------------------------

func startSplashAnimation():
  var splash = SplashAnimation.instantiate()
  add_child(splash)

# ------------------------------------------------------------------------------

func checkEnv():
  if(G.ENV != 'production'):
    prints('⚠️👾 ENV='+G.ENV)

  for cliOptions in OS.get_cmdline_args():
    if(cliOptions == 'local-fox-runner'):
      G.IS_FOX_RUNNER = true

  if(G.ENV == G.PRODUCTION and G.IS_FOX_RUNNER):
    prints('⚠️👾 Started with Fox and production settings.')
