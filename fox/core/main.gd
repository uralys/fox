extends Node

func _ready():
  print('-------------------------------')
  print('[🦊 Fox] 1.0]')
  print('-------------------------------')
  startScreen()

func startScreen():
  Router.openHome()
