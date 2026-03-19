# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

var ScreenFader = preload("res://fox/components/screen-fader.tscn")
var FullscreenLoader = preload("res://fox/components/fullscreen-loader.tscn")
var SettingsPopup = preload('res://src/popups/settings.tscn')
var LanguagesPopup = preload('res://src/popups/languages.tscn')
var _NavState = preload('res://fox/core/nav-state.gd')

# ------------------------------------------------------------------------------

var resourceLoader
var _loadedResources = {}
var fullscreenLoader

signal loaded

# ------------------------------------------------------------------------------

var currentScene = null
var _lastScene = null
var _lastOptions = {}
var _navState = null
var _navFilePath: String = ''

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
  return 0

func onSceneReady():
  pass

# ------------------------------------------------------------------------------
# Navigation state
# ------------------------------------------------------------------------------

func getNavPath() -> Array:
  if _navState:
    return _navState.path
  return []

func setNavPath(path: Array):
  if _navState:
    _navState.path = path.duplicate()
    _persistNavState()

# ------------------------------------------------------------------------------
# Scene navigation
# ------------------------------------------------------------------------------

func restoreOrDefault(defaultAction: Callable):
  var state = _loadPersistedNavState()
  if state:
    var scene = load(state.scene_path)
    _navState = state
    G.log('[Router]> restoring:', state.scene_path, state.path)
    openScene(scene, {})
  else:
    defaultAction.call()

func reloadCurrentScene():
  var state = _loadPersistedNavState()
  if state:
    var scene = load(state.scene_path)
    _navState = state
    G.log('[Router]> hot reloading:', state.scene_path, state.path)
    openScene(scene, {})
  elif _lastScene:
    G.log('[Router]> hot reloading scene...')
    openScene(_lastScene, _lastOptions)

func openScene(scene, options = {}):
  call_deferred("_openScene", scene, options)

func _openScene(scene, options = {}):
  _lastScene = scene
  _lastOptions = options

  var scene_path = scene.resource_path
  if not _navState or _navState.scene_path != scene_path:
    _navState = _NavState.new()
    _navState.scene_path = scene_path
    _persistNavState()

  var previousSceneName = 'none'

  if(currentScene):
    previousSceneName = str(currentScene.name)
    G.log('[Router]> leaving', previousSceneName, '> ---------')

    if(currentScene.has_method('onLeave')):
      currentScene.onLeave(options)

    var timeToWaitOnOpenScene = onOpenScene()
    await Wait.forSomeTime($/root, timeToWaitOnOpenScene).timeout

    $'/root/app/scene'.remove_child(currentScene)
    currentScene.queue_free()

  currentScene = scene.instantiate()
  $'/root/app/scene'.add_child(currentScene)

  onSceneReady()

  if(__.Get('onOpen',options) != null):
    options.onOpen.call()

  if(currentScene.has_method('onOpen')):
    currentScene.onOpen(options)

  G.log('[Router]> ---------- entered:', str(currentScene.name))

# ------------------------------------------------------------------------------
# Nav state persistence
# ------------------------------------------------------------------------------

func _getNavFilePath() -> String:
  if _navFilePath.is_empty():
    _navFilePath = ProjectSettings.globalize_path('res://') + '.nav-state'
  return _navFilePath

func _persistNavState():
  if not _navState:
    return
  var file = FileAccess.open(_getNavFilePath(), FileAccess.WRITE)
  if file:
    file.store_string(_navState.to_json())

func _loadPersistedNavState():
  var fpath = _getNavFilePath()
  if not FileAccess.file_exists(fpath):
    return null
  var content = FileAccess.get_file_as_string(fpath)
  var state = _NavState.new()
  if state.load_json(content):
    return state
  return null

# ------------------------------------------------------------------------------
# Resource loading
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
  loaded.emit()
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
# UI overlays
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
    fullscreenLoader = null

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
