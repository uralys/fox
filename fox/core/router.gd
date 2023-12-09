# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

var loader
var _loadedResources = {}
signal loaded

# ------------------------------------------------------------------------------

var currentScene = null

# ------------------------------------------------------------------------------

func getCurrentSceneName():
  return str(currentScene.name)

func getCurrentScene():
  return currentScene

# ------------------------------------------------------------------------------

func openDefault():
  prints('openDefault() can be overriden to open your default screen when an error occurs.')

# ------------------------------------------------------------------------------

func onOpenScene():
  return null

# ------------------------------------------------------------------------------

func openScene(scene, options = {}):
  call_deferred("_openScene", scene, options)

func _openScene(scene, options = {}):
  var previousSceneName = 'none'

  if(currentScene):
    previousSceneName = str(currentScene.name)

    var timerOnOpenScene = onOpenScene()
    if(timerOnOpenScene):
      await timerOnOpenScene.timeout

    if(currentScene.has_method('onLeave')):
      currentScene.onLeave(options)

    $'/root/app/scene'.remove_child(currentScene)
    currentScene.queue_free()

  currentScene = scene.instantiate()
  prints('[🦊 Router]> leaving', previousSceneName, '> ---------')
  $'/root/app/scene'.add_child(currentScene)

  if(__.Get('onOpen',options) != null):
    options.onOpen.call()

  if(currentScene.has_method('onOpen')):
    currentScene.onOpen(options)
  prints('[🦊 Router]> ---------- entering', str(currentScene.name))

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
