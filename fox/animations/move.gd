# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

class_name Move

# ------------------------------------------------------------------------------

static func from(object, property, fromValue, duration = 0.75, delay = 0, _ease = null):
  var toValue = object[property]
  object[property] = fromValue
  _animate(object, property, fromValue, toValue, duration, delay, _ease)

# ------------------------------------------------------------------------------

static func to(object, property, toValue, duration = 0.75, delay = 0, _ease = null):
  var fromValue = object[property]
  _animate(object, property, fromValue, toValue, duration, delay, _ease)

# ------------------------------------------------------------------------------

static func swing(object, property, toValue, duration = 0.75, delay = 0, _ease = null):
  var easing = _ease
  if(easing == null):
    easing = Tween.EASE_IN_OUT

  var fromValue = object[property]
  _animate(object, property, fromValue, toValue, duration, delay, easing)

  var _timer = Wait.start(object, duration + delay)
  yield(_timer, 'timeout')

  _animate(object, property, toValue, fromValue, duration, 0, easing)

  var _timerBack = Wait.start(object, duration)
  yield(_timerBack, 'timeout')

  swing(object, property, toValue, duration, 0, easing)

# ------------------------------------------------------------------------------

static func _animate(object, property, fromValue, toValue, duration = 0.75, delay = 0, _ease = null):
  if(delay > 0):
    var _timer = Wait.start(object, delay)
    yield(_timer, 'timeout')

  var easing = _ease
  if(easing == null):
    easing = Tween.EASE_OUT

  var tween = Tween.new()
  object.add_child(tween)

  tween.interpolate_property(
    object,
    property,
    fromValue, toValue,
    duration,
    Tween.TRANS_QUAD, easing
  )

  tween.start()
