# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

var loader
var _loadedResources = {}
signal loaded

# ------------------------------------------------------------------------------

var currentScene = null

# ------------------------------------------------------------------------------

var CURTAIN_DURATION = 0.7 #s

var isCurtainOpen = true
var leftCurtain
var rightCurtain

# ------------------------------------------------------------------------------

func _ready():
  leftCurtain = $'/root/app/curtain/left'
  rightCurtain = $'/root/app/curtain/right'

# ------------------------------------------------------------------------------

func getCurrentScene():
  return currentScene

# ------------------------------------------------------------------------------

func openDefault():
  assert(0==1, 'openDefault() must be overriden to open your default screen')

# ------------------------------------------------------------------------------

func _openScene(scene):
  if(currentScene):
    prints('[🦊 Router] <', str(currentScene.name))

    if(isCurtainOpen):
      closeCurtain()
      var _timer = Wait.start(leftCurtain, CURTAIN_DURATION)
      yield(_timer, 'timeout')

    currentScene.queue_free()

  currentScene = scene.instance()
  prints('[🦊 Router] >', str(currentScene.name))
  $'/root/app/scene'.add_child(currentScene)

# ------------------------------------------------------------------------------

func startLoadingResource(path):
  loader = ResourceLoader.load_interactive(path)
  _loadedResources.__loading = path

  if loader == null: # Check for errors.
    openDefault()

func finishedLoadingResource():
  var resource = loader.get_resource()
  _loadedResources[_loadedResources.__loading] = resource
  _loadedResources.__loading = null
  loader = null
  emit_signal('loaded')
  return resource

func getLoadingProgress():
  if loader == null:
    return 1
  return float(loader.get_stage()) / loader.get_stage_count()

func getLoadedResource(path):
  if(_loadedResources.has(path)):
    return _loadedResources[path]
  return null

# ------------------------------------------------------------------------------

func closeCurtain():
  isCurtainOpen = false
  Move.setValue(leftCurtain, 'anchor_right', 0.66, CURTAIN_DURATION)
  Move.setValue(rightCurtain, 'anchor_left', 0.33, CURTAIN_DURATION)

func openCurtain():
  isCurtainOpen = true
  Move.setValue(leftCurtain, 'anchor_right', 0, CURTAIN_DURATION, 0, Tween.EASE_IN)
  Move.setValue(rightCurtain, 'anchor_left', 1, CURTAIN_DURATION, 0, Tween.EASE_IN)
