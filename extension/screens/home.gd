extends Node2D

func _ready():
  $camera.current = true
  for button in $buttons.get_children():
    var num = button.get_index()
    button.connect("pressed", Router, "openPlayground", [num])
