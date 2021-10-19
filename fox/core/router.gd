# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

var CURTAIN_DURATION = 0.7 #s
var currentScene = null

var leftCurtain
var rightCurtain

# ------------------------------------------------------------------------------

func _ready():
  leftCurtain = $'/root/app/curtain/left'
  rightCurtain = $'/root/app/curtain/right'

# ------------------------------------------------------------------------------

func getCurrentScene():
  return currentScene

func prepare():
  return currentScene

# ------------------------------------------------------------------------------

func _openScene(scene):
  if(currentScene):
    print('[🦊 Router]> leaving current' + str(currentScene.name))
    closeCurtain()

    var _timer = Wait.start(leftCurtain, CURTAIN_DURATION)
    yield(_timer, 'timeout')

    currentScene.queue_free()

  currentScene = scene.instance()
  print('[🦊 Router]> ' + str(currentScene.name))
  $'/root/app/scene'.add_child(currentScene)

# ------------------------------------------------------------------------------

func closeCurtain():
  Move.setValue(leftCurtain, 'anchor_right', 0.66, CURTAIN_DURATION)
  Move.setValue(rightCurtain, 'anchor_left', 0.33, CURTAIN_DURATION)

func openCurtain():
  Move.setValue(leftCurtain, 'anchor_right', 0, CURTAIN_DURATION, 0, Tween.EASE_IN)
  Move.setValue(rightCurtain, 'anchor_left', 1, CURTAIN_DURATION, 0, Tween.EASE_IN)
