# ------------------------------------------------------------------------------

extends Node2D

# ------------------------------------------------------------------------------

func onOpen(params):
  print('[🤖 Godox] [Playground] runs')
  if params != null:
    assert(params)
