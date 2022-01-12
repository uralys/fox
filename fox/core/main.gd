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

  randomize() # https://docs.godotengine.org/en/latest/tutorials/math/random_number_generation.html#the-randomize-method
  startSplashAnimation()

# ------------------------------------------------------------------------------

func startSplashAnimation():
  Master.splashScreen = SplashAnimation.instance()
  add_child(Master.splashScreen)

# ------------------------------------------------------------------------------

func checkEnv():
  if(G.ENV != 'production'):
    prints('👾 🔴 ENV='+G.ENV);
  else:
    for cliOptions in OS.get_cmdline_args():
      if(cliOptions == 'local-fox-runner'):
        prints('🔴 Fox runner on production.');
        prints('use "fox switch" to use another preset.');
        prints('Starting aborted.');
        prints('-------------------------------')
        get_tree().quit(0)
        return false

  return true
