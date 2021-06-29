extends Node2D

func _ready():
  $timer.connect("timeout", self, "onTimeout")

func onTimeout():
  $sprite.visible = !$sprite.visible
  print('onTimeout' + str($sprite.visible))
