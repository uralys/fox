# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

class_name Visibility

# -------------------------------- ----------------------------------------------

static func show(object, to = 1, duration = 0.75, delay = 0):
  if(delay > 0):
    var _timer = Wait.start(object, delay)
    yield(_timer, 'timeout')

  var tween = Tween.new()
  object.add_child(tween)
  object.modulate.a = 0
  object.visible = true

  tween.interpolate_property(
    object,
    'modulate:a',
    0, to,
    duration,
    Tween.TRANS_SINE, Tween.EASE_OUT
  )

  tween.start()
  return tween

# ------------------------------------------------------------------------------

static func fadeOut(object, duration = 0.75, delay = 0):
  if(delay > 0):
    var _timer = Wait.start(object, delay)
    yield(_timer, 'timeout')

  var tween = Tween.new()
  object.add_child(tween)

  tween.interpolate_property(
    object,
    'modulate:a',
    object.modulate.a, 0,
    duration,
    Tween.TRANS_QUAD, Tween.EASE_OUT
  )

  tween.start()
