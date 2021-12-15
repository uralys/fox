extends Node

var SplashAnimation = preload('res://fox/animations/splash-animation.tscn')

func _ready():
  print('-------------------------------')
  print('[🦊 1.0]')
  prints('viewport:', get_viewport().size)
  prints('window:', OS.get_window_size())
  print('-------------------------------')
  randomize() # https://docs.godotengine.org/en/latest/tutorials/math/random_number_generation.html#the-randomize-method
  startSplashAnimation()

func startSplashAnimation():
  Master.splashScreen = SplashAnimation.instance()
  add_child(Master.splashScreen)
