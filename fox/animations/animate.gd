# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

class_name Animate

# ==============================================================================

static func bounce(object):
  if(object.get('scale')):
    _bounceProperty(object, 'scale')
  elif(object.get('rect_scale')):
    _bounceProperty(object, 'rect_scale')
  else:
    prints('❌ scale/rect_scale not found on this object; cannot bounce.')

# ------------------------------------------------------------------------------

static func from(object, _options):
  var options = _options.duplicate()

  var propertyPath = _options.propertyPath
  var fromValue = _options.fromValue

  __.Set(fromValue, propertyPath, object)
  options.toValue = __.Get(propertyPath, object)

  _animate(object, options)
  yield(object, 'animationDone')

# ------------------------------------------------------------------------------

static func to(object, _options):
  var options = _options.duplicate()

  options.fromValue = __.Get(options.propertyPath, object)
  _animate(object, options)
  yield(object, 'animationDone')

# ------------------------------------------------------------------------------

static func show(object, duration = 0.3, delay = 0):
  _animate(object, {
    propertyPath = 'modulate:a',
    fromValue = object.modulate.a,
    toValue = 1,
    duration = duration,
    delay = delay
  })

# ------------------------------------------------------------------------------

static func hide(object, duration = 0.3, delay = 0):
  _animate(object, {
    propertyPath = 'modulate:a',
    fromValue = object.modulate.a,
    toValue = 0,
    duration = duration,
    delay = delay
  })

# ------------------------------------------------------------------------------

static func appear(object, delay):
  var aimY = object.position.y
  object.modulate.a = 0
  object.position.y += 30

  var timer = Wait.start(object, delay)
  yield(timer, 'timeout')

  _animate(object, {
    propertyPath = 'modulate:a',
    fromValue = 0,
    toValue = 1,
    duration = 0.2,
    transition = Tween.TRANS_LINEAR,
    easing = Tween.EASE_OUT
  })

  _animate(object, {
    propertyPath = 'scale',
    fromValue = Vector2(0.01,0.01),
    toValue =  object.scale,
    duration = 0.2,
    transition = Tween.TRANS_LINEAR,
    easing = Tween.EASE_OUT
  })

  _animate(object, {
    propertyPath = 'position:y',
    fromValue = object.position.y,
    toValue = aimY,
    duration = 1.2,
    transition = Tween.TRANS_ELASTIC,
    easing = Tween.EASE_OUT
  })

  timer = Wait.start(object, 1.2)
  yield(timer, 'timeout')

  if(object.has_method('onSpawn')):
    object.onSpawn()

# ==============================================================================

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

  to(object, {
    propertyPath = property,
    toValue = fromScale + Vector2(upScale, upScale),
    duration = duration
  })

  var _timer = Wait.start(object, duration)
  yield(_timer, 'timeout')

  to(object, {
    propertyPath = property,
    toValue = fromScale,
    duration = duration
  })

  _timer = Wait.start(object, duration)
  yield(_timer, 'timeout')

  if(times > 1):
    _bounce(object, fromScale, upScale, stepDuration, property, times - 1)

# ------------------------------------------------------------------------------

static func _stoppedSwinging(object):
  return object.get('swinging') != null and not object.swinging

static func swing(object, _options):
  var options = _options.duplicate()

  if(_stoppedSwinging(object)):
    return

  # --------
  # swing forth

  options.fromValue = __.Get(options.propertyPath, object)
  options.signalToWait = 'swing1Done'

  _animate(object, options)
  yield(object, 'swing1Done')

  if(_stoppedSwinging(object)):
    return

  # --------
  # swing back

  var currentToValue = options.toValue
  var currentFromValue = options.fromValue
  options.fromValue = currentToValue
  options.toValue = currentFromValue
  options.delay = 0
  options.signalToWait = 'swing2Done'

  _animate(object, options)
  yield(object, 'swing2Done')

  if(_stoppedSwinging(object)):
    return

  # --------
  # loop

  swing(object, _options)

# ------------------------------------------------------------------------------

const ANIMATION_DONE = 'animationDone'

static func _animate(object, options):
  var propertyPath = options.propertyPath
  var fromValue = options.get('fromValue')
  var toValue = options.get('toValue')

  var delay = options.delay if options.get('delay') else 0
  var duration = options.duration if options.get('duration') else 0.75

  var easing = options.easing if options.get('easing') else Tween.EASE_OUT
  var transition = options.transition if options.get('transition') else Tween.TRANS_QUAD

  var SIGNAL_ON_DONE = options.signalToWait if options.get('signalToWait') else ANIMATION_DONE

  if(not object.has_signal(SIGNAL_ON_DONE)):
    object.add_user_signal(SIGNAL_ON_DONE)

  # --------

  var fields = Array(propertyPath.split('.'))
  var property = fields.pop_back()

  # --------

  var nestedToAnimate = object
  if(fields.size() > 0):
    var nestedPath = PoolStringArray(fields).join('.')
    nestedToAnimate = __.Get(nestedPath, object)

  # --------

  if(delay > 0):
    var _timer = Wait.start(object, delay)
    yield(_timer, 'timeout')

  # --------

  var tween = Tween.new()
  object.add_child(tween)

  # --------

  tween.interpolate_property(
    nestedToAnimate,
    property,
    fromValue, toValue,
    duration,
    transition, easing
  )

  tween.start()

  # --------

  yield(tween, 'tween_completed')
  object.remove_child(tween)
  tween.queue_free()

  object.emit_signal(SIGNAL_ON_DONE)
