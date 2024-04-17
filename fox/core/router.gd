# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

var ScreenFader = preload("res://fox/components/screen-fader.tscn")
var FullscreenLoader = preload("res://fox/components/fullscreen-loader.tscn")
var SettingsPopup = preload('res://src/popups/settings.tscn')
var LanguagesPopup = preload('res://src/popups/languages.tscn')

# ------------------------------------------------------------------------------

var resourceLoader
var _loadedResources = {}
var fullscreenLoader

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
  G.log('openDefault() can be overriden to open your default screen when an error occurs.')

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
    G.log('[🦊 Router]> leaving', previousSceneName, '> ---------')

    if(currentScene.has_method('onLeave')):
      currentScene.onLeave(options)

    var timerOnOpenScene = onOpenScene()
    if(timerOnOpenScene):
      await timerOnOpenScene.timeout

    $'/root/app/scene'.remove_child(currentScene)
    currentScene.queue_free()

  currentScene = scene.instantiate()
  $'/root/app/scene'.add_child(currentScene)

  if(__.Get('onOpen',options) != null):
    options.onOpen.call()

  if(currentScene.has_method('onOpen')):
    currentScene.onOpen(options)
  G.log('[🦊 Router]> ---------- entered:', str(currentScene.name))

# ------------------------------------------------------------------------------

func startLoadingResource(path):
  resourceLoader = ResourceLoader.load_threaded_request(path)
  _loadedResources.__loading = path

  if resourceLoader == null: # Check for errors.
    openDefault()

func finishedLoadingResource():
  var resource = resourceLoader.get_resource()
  _loadedResources[_loadedResources.__loading] = resource
  _loadedResources.__loading = null
  resourceLoader = null
  emit_signal('loaded')
  return resource

func getLoadingProgress():
  if resourceLoader == null:
    return 1
  return float(resourceLoader.get_stage()) / resourceLoader.get_stage_count()

func getLoadedResource(path):
  if(_loadedResources.has(path)):
    return _loadedResources[path]
  return null

# ------------------------------------------------------------------------------

func useScreenFader(duration:float = 0.75):
  var fader = ScreenFader.instantiate()
  fader.duration = duration
  getCurrentScene().add_child(fader)

# ------------------------------------------------------------------------------

func showLoader():
  fullscreenLoader = FullscreenLoader.instantiate()
  $/root/app.add_child(fullscreenLoader)

func hideLoader():
  if(fullscreenLoader):
    fullscreenLoader.remove()

# ------------------------------------------------------------------------------

func openSettings():
  var settings = SettingsPopup.instantiate()
  $/root/app/popups.add_child(settings)
  settings.show()

func openLanguages(options = {}):
  var languages = LanguagesPopup.instantiate()
  languages.onClose = __.Get('onClose', options)
  languages.welcome = __.Get('welcome', options)

  $/root/app/popups.add_child(languages)
  languages.show()
