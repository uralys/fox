# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

class_name Scale

# ------------------------------------------------------------------------------

static func backAndForth(object, from, to, duration = 2, delay = 0):
  if(delay > 0):
    var _timer = Wait.start(object, delay)
    yield(_timer, 'timeout')

  var tween = Tween.new()
  object.add_child(tween)

  tween.interpolate_property(
    object,
    'scale',
    from, to,
    float(duration)/2,
    Tween.TRANS_QUAD, Tween.EASE_OUT
  )

  tween.start()
  yield(tween, 'tween_completed')

  tween.interpolate_property(
    object,
    'scale',
    to, from,
    float(duration),
    Tween.TRANS_QUAD, Tween.EASE_OUT
  )

  tween.start()
