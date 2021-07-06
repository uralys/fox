extends Node

func _ready():
  print('-------------------------------')
  print('[🤖 Godox] 1.0]')
  print('-------------------------------')
  startScreen()

func startScreen():
  Router.openHome()
