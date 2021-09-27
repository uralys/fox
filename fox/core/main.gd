extends Node

func _ready():
  print('-------------------------------')
  print('[🦊 1.0]')
  print('-------------------------------')
  randomize() # https://docs.godotengine.org/en/latest/tutorials/math/random_number_generation.html#the-randomize-method
  startScreen()

func startScreen():
  Router.openHome()
