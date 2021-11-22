# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

var loader
var _loadedResources = {}
signal loaded

# ------------------------------------------------------------------------------

var currentScene = null

# ------------------------------------------------------------------------------

var CURTAIN_DURATION = 0.7
var isCurtainOpen = true

# ------------------------------------------------------------------------------

onready var curtain = $'/root/app/curtain'
onready var leftCurtain = $'/root/app/curtain/left'
onready var rightCurtain = $'/root/app/curtain/right'

# ------------------------------------------------------------------------------

func getCurrentScene():
  return currentScene

# ------------------------------------------------------------------------------

func openDefault():
  assert(0==1, 'openDefault() must be overriden to open your default screen')

# ------------------------------------------------------------------------------

func _openScene(scene):
  var previousSceneName = 'none'

  if(currentScene):
    previousSceneName = str(currentScene.name)

    if(isCurtainOpen):
      closeCurtain()
      var _timer = Wait.start(leftCurtain, CURTAIN_DURATION)
      yield(_timer, 'timeout')

    $'/root/app/scene'.remove_child(currentScene)
    currentScene.queue_free()

  currentScene = scene.instance()
  prints('[🦊 Router]>', previousSceneName, '>', str(currentScene.name))
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

  Animate.to(leftCurtain, {
    propertyPath = 'anchor_right',
    toValue = 0.66,
    duration = CURTAIN_DURATION
  })

  Animate.to(rightCurtain, {
    propertyPath = 'anchor_left',
    toValue = 0.33,
    duration = CURTAIN_DURATION
  })

func openCurtain():
  isCurtainOpen = true
  if(curtain.has_node('decoration')):
    curtain.remove_child(curtain.get_node('decoration'))

  Animate.to(leftCurtain, {
    propertyPath = 'anchor_right',
    toValue = 0,
    duration = CURTAIN_DURATION,
    easing = Tween.EASE_IN
  })

  Animate.to(rightCurtain, {
    propertyPath = 'anchor_left',
    toValue = 1,
    duration = CURTAIN_DURATION,
    easing = Tween.EASE_IN
  })
