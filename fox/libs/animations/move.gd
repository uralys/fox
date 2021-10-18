# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

class_name Move

# -------------------------------- ----------------------------------------------

static func to(object, to:Vector2, duration = 0.75, delay = 0):
  if(delay > 0):
    var _timer = Wait.start(object, delay)
    yield(_timer, 'timeout')

  var tween = Tween.new()
  object.add_child(tween)

  tween.interpolate_property(
    object,
    'position',
    object.position, to,
    duration,
    Tween.TRANS_QUAD, Tween.EASE_OUT
  )

  tween.start()
