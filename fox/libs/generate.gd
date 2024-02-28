# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

var ELEMENTS = preload('res://assets/name-elements.json').data

# ------------------------------------------------------------------------------

func uid(prefix):
  var _prefix = ''
  if (prefix):
    _prefix = prefix + '-'

  return _prefix + str(Time.get_unix_time_from_system()) + '-' + str(Time.get_ticks_msec()) + '-' + str(randi() % 900000 + 100000)

# ------------------------------------------------------------------------------

func name():
  if(!ELEMENTS):
    return 'Player'

  var _adjective = ELEMENTS.adjectives[randi() % ELEMENTS.adjectives.size()]
  var _name = ELEMENTS.names[randi() % ELEMENTS.names.size()]

  return _adjective + _name
