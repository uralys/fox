# ------------------------------------------------------------------------------

extends Node2D

# ------------------------------------------------------------------------------

func onOpen(_params):
  print('[🤖 Godox] [Playground] onOpen')

  move_child($devHUD, get_child_count() -1)
