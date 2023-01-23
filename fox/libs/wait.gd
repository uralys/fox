# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

class_name Wait

# ------------------------------------------------------------------------------

static func start(Callable(parent,timetoWait)):
  var _Timer = Timer.new()
  parent.add_child(_Timer)
  _Timer.start(timetoWait);
  return _Timer

# ------------------------------------------------------------------------------
