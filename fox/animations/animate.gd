# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

class_name Animate

# ------------------------------------------------------------------------------

static func bounce(object):
  if(object.get('scale')):
    _bounceProperty(object, 'scale')
  elif(object.get('rect_scale')):
    _bounceProperty(object, 'rect_scale')
  else:
    prints('❌ scale/rect_scale not found on this object; cannot bounce.')

# ------------------------------------------------------------------------------

static func from(object, propertyPath, fromValue, duration = 0.75, delay = 0, _ease = null):
  var toValue = __.Get(propertyPath, object)
  __.Set(fromValue, propertyPath, object)
  _animate(object, propertyPath, fromValue, toValue, duration, delay, _ease)

# ------------------------------------------------------------------------------

static func to(object, propertyPath, toValue, duration = 0.75, delay = 0, _ease = null):
  var fromValue = __.Get(propertyPath, object)
  _animate(object, propertyPath, fromValue, toValue, duration, delay, _ease)

# ------------------------------------------------------------------------------

static func show(object, duration = 0.3, delay = 0):
  _animate(object, 'modulate:a', object.modulate.a, 1, duration, delay)

# ------------------------------------------------------------------------------

static func hide(object, duration = 0.3, delay = 0):
  _animate(object, 'modulate:a', object.modulate.a, 0, duration, delay)

# ------------------------------------------------------------------------------

static func _getInitialValue(object, property):
  var initialValue = object[property];
  var metaName = 'initial-'+property;
  if(object.has_meta(metaName)):
    initialValue = object.get_meta(metaName)
  else:
    object.set_meta(metaName, initialValue)

  return initialValue

# ------------------------------------------------------------------------------

static func _bounceProperty(object, property):
  var initialScale = _getInitialValue(object, property);
  _bounce(object, initialScale, 0.05, 0.2, property)

# ------------------------------------------------------------------------------

static func _bounce(object, fromScale, upScale = 0.06, stepDuration = 0.25, property = "scale", times = 1):
  var duration = float(stepDuration)/2

  to(object, property, fromScale + Vector2(upScale, upScale), duration )

  var _timer = Wait.start(object, duration)
  yield(_timer, 'timeout')

  to(object, property, fromScale, duration )

  _timer = Wait.start(object, duration)
  yield(_timer, 'timeout')

  if(times > 1):
    _bounce(object, fromScale, upScale, stepDuration, property, times - 1)

# ------------------------------------------------------------------------------

static func _stoppedSwinging(object):
  return object.get('swinging') != null and not object.swinging

static func swing(object, propertyPath, toValue, duration = 0.75, delay = 0, _ease = null):
  var easing = _ease
  if(easing == null):
    easing = Tween.EASE_IN_OUT

  if(_stoppedSwinging(object)):
    return

  var fromValue = __.Get(propertyPath, object)
  _animate(object, propertyPath, fromValue, toValue, duration, delay, easing)

  var _timer = Wait.start(object, duration + delay)
  yield(_timer, 'timeout')

  if(_stoppedSwinging(object)):
    return

  _animate(object, propertyPath, toValue, fromValue, duration, 0, easing)

  var _timerBack = Wait.start(object, duration)
  yield(_timerBack, 'timeout')

  if(_stoppedSwinging(object)):
    return

  swing(object, propertyPath, toValue, duration, 0, easing)

# ------------------------------------------------------------------------------

static func _animate(object, propertyPath, fromValue, toValue, duration = 0.75, delay = 0, _ease = null):
  var fields = Array(propertyPath.split('.'))
  var property = fields.pop_back()

  var nestedToAnimate = object

  if(fields.size() > 0):
    var nestedPath = PoolStringArray(fields).join('.')
    nestedToAnimate = __.Get(nestedPath, object)

  if(delay > 0):
    var _timer = Wait.start(object, delay)
    yield(_timer, 'timeout')

  var easing = _ease
  if(easing == null):
    easing = Tween.EASE_OUT

  var tween = Tween.new()
  object.add_child(tween)

  prints('interpolate', {
  property=property,
    fromValue=fromValue, toValue=toValue,
    duration=duration,
    easing=easing
  })

  tween.interpolate_property(
    nestedToAnimate,
    property,
    fromValue, toValue,
    duration,
    Tween.TRANS_QUAD, easing
  )

  tween.start()

  yield(tween, 'tween_completed')
  object.remove_child(tween)
  tween.queue_free()
