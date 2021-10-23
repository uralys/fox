# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

class_name Move

# ------------------------------------------------------------------------------

static func from(object, propertyPath, fromValue, duration = 0.75, delay = 0, _ease = null):
  var toValue = __.getAtPath(propertyPath, object)
  __.setAtPath(fromValue, propertyPath, object)
  _animate(object, propertyPath, fromValue, toValue, duration, delay, _ease)

# ------------------------------------------------------------------------------

static func to(object, propertyPath, toValue, duration = 0.75, delay = 0, _ease = null):
  var fromValue = __.getAtPath(propertyPath, object)
  _animate(object, propertyPath, fromValue, toValue, duration, delay, _ease)

# ------------------------------------------------------------------------------

static func swing(object, propertyPath, toValue, duration = 0.75, delay = 0, _ease = null):
  var easing = _ease
  if(easing == null):
    easing = Tween.EASE_IN_OUT

  if(not object.swinging):
    return

  var fromValue = __.getAtPath(propertyPath, object)
  _animate(object, propertyPath, fromValue, toValue, duration, delay, easing)

  var _timer = Wait.start(object, duration + delay)
  yield(_timer, 'timeout')

  if(not object.swinging):
    return

  _animate(object, propertyPath, toValue, fromValue, duration, 0, easing)

  var _timerBack = Wait.start(object, duration)
  yield(_timerBack, 'timeout')

  if(not object.swinging):
    return

  swing(object, propertyPath, toValue, duration, 0, easing)

# ------------------------------------------------------------------------------

static func _animate(object, propertyPath, fromValue, toValue, duration = 0.75, delay = 0, _ease = null):
  var fields = Array(propertyPath.split('.'))
  var property = fields.pop_back()

  var nestedToAnimate = object

  if(fields.size() > 0):
    var nestedPath = PoolStringArray(fields).join('.')
    nestedToAnimate = __.getAtPath(nestedPath, object)

  if(delay > 0):
    var _timer = Wait.start(object, delay)
    yield(_timer, 'timeout')

  var easing = _ease
  if(easing == null):
    easing = Tween.EASE_OUT

  var tween = Tween.new()
  object.add_child(tween)

  tween.interpolate_property(
    nestedToAnimate,
    property,
    fromValue, toValue,
    duration,
    Tween.TRANS_QUAD, easing
  )

  tween.start()
