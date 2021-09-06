# ------------------------------------------------------------------------------

extends Node2D

# ------------------------------------------------------------------------------

func _ready():
  print('[🦊 Playground] ready')

  if not G.DEBUG:
    $debugHUD.visible = false

  move_child($debugHUD, get_child_count() -1)
