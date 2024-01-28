# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

class_name Wait

# ------------------------------------------------------------------------------

static func forSomeTime(parent, timeInSec: float):
  var _Timer = Timer.new()
  parent.add_child(_Timer)
  _Timer.start(timeInSec);
  return _Timer

# ------------------------------------------------------------------------------

# we need the object to have a `params` Dictionary to store the timer
static func withTimer(timetoWait: float, object: Variant, onTimeout: Callable):
  var params = __.Get('params', object)

  if(!params):
    assert(false, 'withTimeout requires the object to have a `params` Dictionary')
    return

  var timer = __.Get('timer', params)

  if(timer):
    timer.stop()
  else:
    timer = Timer.new()
    object.add_child(timer)
    object.params.timer = timer

    timer.timeout.connect(func():
      timer.stop()
      onTimeout.call()
    )

  timer.start(timetoWait)
