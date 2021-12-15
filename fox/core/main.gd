extends Node

func _ready():
  print('-------------------------------')
  print('[🦊 1.0]')
  prints('viewport:', get_viewport().size)
  prints('window:', OS.get_window_size())
  print('-------------------------------')
  randomize() # https://docs.godotengine.org/en/latest/tutorials/math/random_number_generation.html#the-randomize-method

  var splashScreen = load('res://fox/animations/splash-animation.tscn')
  Master.splashScreen = splashScreen.instance()
  add_child(Master.splashScreen)

  prints('> splashScreen');
  print('-------------------------------')
