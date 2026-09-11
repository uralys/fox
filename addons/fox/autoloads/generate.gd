# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

# Where the adjective/name lists live, inside the CONSUMING game. The default
# keeps every existing project working untouched; a game that stores them
# elsewhere overrides the setting in its project.godot.
const NAME_ELEMENTS_SETTING := 'fox/generate/name_elements_path'
const DEFAULT_NAME_ELEMENTS_PATH := 'res://assets/name-elements.json'

# Loaded on first use, never at script load: a framework autoload must not touch
# a game's disk layout just to be registered.
var _elements = null
var _elements_loaded := false

# ------------------------------------------------------------------------------

func uid(prefix):
  var _prefix = ''
  if (prefix):
    _prefix = prefix + '-'

  return _prefix + str(Time.get_unix_time_from_system()) + '-' + str(Time.get_ticks_msec()) + '-' + str(randi() % 900000 + 100000)

# ------------------------------------------------------------------------------

func name():
  var elements = _get_elements()

  if(!elements):
    return 'Player'

  var _adjective = elements.adjectives[randi() % elements.adjectives.size()]
  var _name = elements.names[randi() % elements.names.size()]

  return _adjective + _name

# ------------------------------------------------------------------------------

func _get_elements():
  if(_elements_loaded):
    return _elements

  _elements_loaded = true

  var path = ProjectSettings.get_setting(NAME_ELEMENTS_SETTING, DEFAULT_NAME_ELEMENTS_PATH)

  if(!FileAccess.file_exists(path)):
    G.log('[Generate] no name elements at', path, '- name() falls back to Player')
    return _elements

  var resource = load(path)

  if(!resource or !('data' in resource)):
    G.log('[Generate] could not read name elements at', path, '- name() falls back to Player')
    return _elements

  _elements = resource.data
  return _elements
