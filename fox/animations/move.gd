# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

class_name Move

# ------------------------------------------------------------------------------

static func addValue(object, property, valueToAdd, duration = 0.75, delay = 0, _ease = null):
  var fromValue = object[property]
  var toValue = fromValue + valueToAdd
  _animate(object, property, fromValue, toValue, duration, delay, _ease)

# ------------------------------------------------------------------------------

static func setValue(object, property, valueToSet, duration = 0.75, delay = 0, _ease = null):
  var fromValue = object[property]
  var toValue = valueToSet
  _animate(object, property, fromValue, toValue, duration, delay, _ease)

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
