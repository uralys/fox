# ------------------------------------------------------------------------------

extends Node2D

# ------------------------------------------------------------------------------

func onOpen(_params):
  print('[🦊 Fox] [Playground] onOpen')

  move_child($debugHUD, get_child_count() -1)
