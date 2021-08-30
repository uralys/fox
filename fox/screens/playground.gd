# ------------------------------------------------------------------------------

extends Node2D

# ------------------------------------------------------------------------------

func onOpen(_params):
  print('[🦊 Playground] onOpen')

  if not G.DEBUG:
    $debugHUD.visible = false

  move_child($debugHUD, get_child_count() -1)
