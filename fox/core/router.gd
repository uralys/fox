# ------------------------------------------------------------------------------
# https://docs.godotengine.org/en/stable/getting_started/step_by_step/singletons_autoload.html
# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

var home = preload("res://fox/screens/home.tscn")
var playground = preload("res://fox/screens/playground.tscn")

# ------------------------------------------------------------------------------

var currentScene = null

# ------------------------------------------------------------------------------

func openHome():
  call_deferred("_openScene", home)

func openPlayground():
  call_deferred("_openScene", playground)

# ------------------------------------------------------------------------------

func _openScene(scene):
  if currentScene != null:
    currentScene.queue_free()

  # Instance the new scene.
  currentScene = scene.instance()
  print('[🦊 Router]> ' + str(currentScene.name))

  # Add it to the active scene, as child of root.
  get_tree().get_root().add_child(currentScene)

  # Optionally, to make it compatible with the SceneTree.change_scene() API.
  get_tree().set_current_scene(currentScene)
