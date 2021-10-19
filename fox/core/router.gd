# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

var currentScene = null

# ------------------------------------------------------------------------------

func getCurrentScene():
  return currentScene

func prepare():
  return currentScene

# ------------------------------------------------------------------------------

func _openScene(scene):
  if currentScene != null:
    currentScene.queue_free()

  # Instance the new scene.
  currentScene = scene.instance()
  print('[🦊 Router]> ' + str(currentScene.name))


  var leftCurtain = $'/root/app/curtain/left'
  var rightCurtain = $'/root/app/curtain/right'

  Move.addValue(leftCurtain, 'anchor_right', +0.66)
  Move.addValue(rightCurtain, 'anchor_left', -0.66)

  $'/root/app/scene'.add_child(currentScene)
