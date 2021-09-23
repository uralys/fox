# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

var currentScene = null

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
