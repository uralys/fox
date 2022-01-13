extends Node

var SplashAnimation = preload('res://fox/animations/splash-animation.tscn')

func _ready():
  prints('-------------------------------')
  var foxVersion = ProjectSettings.get_setting('fox/version')
  foxVersion = foxVersion if foxVersion else ''
  prints('[🦊 Fox]', foxVersion)
  prints('-------------------------------')
  prints('viewport:', get_viewport().size)
  prints('window:', OS.get_window_size())
  prints('-------------------------------')

  G.BUNDLE_ID = ProjectSettings.get_setting('bundle/id')
  G.ENV = ProjectSettings.get_setting('bundle/env')
  G.VERSION = ProjectSettings.get_setting('bundle/version')
  G.VERSION_CODE = ProjectSettings.get_setting('bundle/versionCode')

  if(G.ENV != 'production'):
    prints('⚠️👾 ENV='+G.ENV)

  # -----------------------------------

  checkEnv()
  randomize() # https://docs.godotengine.org/en/latest/tutorials/math/random_number_generation.html#the-randomize-method
  startSplashAnimation()

# ------------------------------------------------------------------------------

func startSplashAnimation():
  Master.splashScreen = SplashAnimation.instance()
  add_child(Master.splashScreen)

# ------------------------------------------------------------------------------

func checkEnv():
  for cliOptions in OS.get_cmdline_args():
    if(cliOptions == 'local-fox-runner'):
      G.IS_FOX_RUNNER = true

  if(G.ENV == G.PRODUCTION and G.IS_FOX_RUNNER):
    prints('⚠️👾 Fox runner on production.')
