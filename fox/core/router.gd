# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

var loader
var _loadedResources = {}
signal loaded

# ------------------------------------------------------------------------------

var currentScene = null

# ------------------------------------------------------------------------------

func getCurrentScene():
  return currentScene

# ------------------------------------------------------------------------------

func openDefault():
  assert(0==1) #,'openDefault() must be overriden to open your default screen')

# ------------------------------------------------------------------------------

func onOpenScene():
  return null

# ------------------------------------------------------------------------------

func _openScene(scene, options = {}):
  var previousSceneName = 'none'

  if(currentScene):
    previousSceneName = str(currentScene.name)

    var timerOnOpenScene = onOpenScene()
    if(timerOnOpenScene):
      await timerOnOpenScene.timeout

    $'/root/app/scene'.remove_child(currentScene)
    currentScene.queue_free()

  currentScene = scene.instantiate()
  prints('[🦊 Router]>', previousSceneName, '>', str(currentScene.name))
  $'/root/app/scene'.add_child(currentScene)

  if(currentScene.has_method('onOpen')):
    currentScene.onOpen(options)

# ------------------------------------------------------------------------------

func startLoadingResource(path):
  loader = ResourceLoader.load_threaded_request(path)
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
