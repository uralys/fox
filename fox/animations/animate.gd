# ------------------------------------------------------------------------------
# Tweening curves:
# https://github.com/wandomPewlin/godotTweeningCheatSheet

extends Node

# ------------------------------------------------------------------------------

class_name Animate

# ------------------------------------------------------------------------------

const ANIMATION_DONE = 'animationDone'

# ==============================================================================

# mandatory options = {propertyPath, fromValue}
static func from(object, _options):
  var options = _options.duplicate()

  var propertyPath = options.propertyPath
  var fromValue = options.fromValue

  options.toValue = __.Get(propertyPath, object)
  __.Set(fromValue, propertyPath, object)
  if(not options.get('signalToWait')): options.signalToWait = ANIMATION_DONE

  _animate(object, options)
  # await object.options.signalToWait

# ------------------------------------------------------------------------------

# mandatory options = {propertyPath, toValue}
static func to(object, _options):
  return await _processAnimations(object, Animate._to, _options)

# ------------------------------------------------------------------------------

# mandatory options = {propertyPath, toValue}
static func toAndBack(object, _options):
  var options = _options.duplicate()
  var propertyPath = options.propertyPath

  var totalDuration = __.GetOr(0.5, 'duration', options)
  var duration = float(totalDuration)/2
  var fromValue = object[propertyPath]

  options.duration = duration
  to(object, options)

  await Wait.forSomeTime(object, duration).timeout

  options.toValue = fromValue
  to(object, options)

# ------------------------------------------------------------------------------

static func show(object, duration = 0.3, delay = 0, doNotHide = false):
  if(not object):
    prints('warning: trying to Animate.show a Nil object')
    return

  object.modulate.a = 0
  if(not doNotHide):
    object.visible = false

  if(delay > 0):
    await Wait.forSomeTime(object, delay).timeout

  object.visible = true

  _animate(object, {
    propertyPath = 'modulate:a',
    fromValue = object.modulate.a,
    toValue = 1,
    duration = duration
  })

# ------------------------------------------------------------------------------

static func hide(object:Variant, duration:float = 0.3, delay:float = 0):
  _animate(object, {
    propertyPath = 'modulate:a',
    fromValue = object.modulate.a,
    toValue = 0,
    duration = duration,
    delay = delay
  })

  await Signal(object, Animate.ANIMATION_DONE)
  object.visible = false

# ------------------------------------------------------------------------------

# maybe too specific to Lockey Land
static func appear(object, delay = 0):
  var initialScale = _getInitialValue(object, object.scale);
  var aimY = object.position.y

  object.modulate.a = 0
  object.position.y += 30

  if(not object.has_signal(ANIMATION_DONE)):
    object.add_user_signal(ANIMATION_DONE)

  await Wait.forSomeTime(object, delay).timeout

  _animate(object, {
    propertyPath = 'modulate:a',
    fromValue = 0,
    toValue = 1,
    duration = 0.2,
    transition = Tween.TRANS_LINEAR,
    easing = Tween.EASE_OUT
  })

  _animate(object, {
    propertyPath = object.scale,
    fromValue = Vector2(0.01,0.01),
    toValue = initialScale,
    duration = 0.2,
    transition = Tween.TRANS_LINEAR,
    easing = Tween.EASE_OUT,
    signalToWait = 'appeared' # the elastic checked y is only smoothing, 'appear' is visually done at this point
  })

  _animate(object, {
    propertyPath = 'position',
    fromValue = object.position,
    toValue = Vector2(object.position.x, aimY),
    duration = 1.2,
    transition = Tween.TRANS_ELASTIC,
    easing = Tween.EASE_OUT,
  })

  await object.appeared
  if(object.has_method('onAppear')):
    object.onAppear()

  object.emit_signal(ANIMATION_DONE)

# --------

# maybe too specific to Lockey Land
static func disappear(object, delay = 0):
  var initialScale = _getInitialValue(object, object.scale);

  _animate(object, {
    propertyPath = 'modulate:a',
    fromValue = 1,
    toValue = 0,
    delay = delay + 0.35,
    duration = 0.3,
    transition = Tween.TRANS_LINEAR,
    easing = Tween.EASE_OUT,
    signalToWait = 'disappeared'
  })

  _animate(object, {
    propertyPath = object.scale,
    fromValue = initialScale,
    toValue = Vector2(0.01,0.01),
    delay = delay + 0.3,
    duration = 0.15,
    transition = Tween.TRANS_QUAD,
  easing = Tween.EASE_IN
  })

  toAndBack(object, {
    propertyPath = 'position',
    toValue = object.position + Vector2(0, 10),
    duration = 2,
    transition = Tween.TRANS_ELASTIC,
    delay = delay
  })

  await object.disappeared
  if(object.has_method('onDisappear')):
    object.onDisappear()

# ------------------------------------------------------------------------------

static func zoomIn(object, _options = {}):
  return await _processAnimations(object, Animate._zoomIn, _options)

static func _zoomIn(object, _options = {}):
  var duration = __.GetOr(0.5, 'duration', _options)
  var fromScaleRatio = __.GetOr(0.9, 'fromScaleRatio', _options)

  var aimedScale = object.scale
  var startScale = object.scale * fromScaleRatio
  object.scale = startScale

  to(object, {
    propertyPath = 'scale',
    toValue = aimedScale,
    duration = duration,
    easing = Tween.EASE_OUT
  })

# ------------------------------------------------------------------------------

static func bounce(object, duration = 0.25, upScale = 0.05):
  var initialScale = object.scale;
  return await _bounce(object, initialScale, upScale, duration)

# ==============================================================================

static func _processAnimations(object, callable: Callable, _options = {}):
  if(typeof(_options) != TYPE_DICTIONARY):
    G.log('❌ [b][color=pink] Animate options must be of TYPE_DICTIONARY[/color][/b] ');
    G.log('[color=pink]found:[/color] ', {options=_options});
    return null

  if(typeof(object) == TYPE_ARRAY):
    var __onFinished = _options.get('onFinished')
    var delayBetweenElements = __.GetOr(0, 'delayBetweenElements', _options)
    _options.onFinished = null

    while object.size() > 0:
      var o = object.pop_front()

      if(object.size() == 0):
        _options.onFinished = __onFinished

      callable.call(o, _options)
      if(delayBetweenElements > 0):
        await Wait.forSomeTime(o, delayBetweenElements).timeout

  else:
    return callable.call(object, _options)

# ------------------------------------------------------------------------------

static func _to(object, _options):
  var options = _options.duplicate()
  options.fromValue = __.Get(options.propertyPath, object)
  if(not options.get('signalToWait')): options.signalToWait = ANIMATION_DONE

  _animate(object, options)
  # await object.options.signalToWait

static func _getInitialValue(object, property):
  var initialValue = object[property];
  var metaName = 'initial_'+property;
  if(object.has_meta(metaName)):
    initialValue = object.get_meta(metaName)
  else:
    object.set_meta(metaName, initialValue)

  return initialValue

# ------------------------------------------------------------------------------

static func _bounce(object, fromScale, upScale = 0.06, stepDuration = 0.25, times = 1):
  var duration = float(stepDuration)/2

  to(object, {
    propertyPath = 'scale',
    toValue = fromScale + Vector2(upScale, upScale),
    duration = duration
  })

  await Wait.forSomeTime(object, duration).timeout

  to(object, {
    propertyPath = 'scale',
    toValue = fromScale,
    duration = duration
  })

  await Wait.forSomeTime(object, duration).timeout

  if(times > 1):
    _bounce(object, fromScale, upScale, stepDuration, times - 1)

# ------------------------------------------------------------------------------

static func _stoppedSwinging(object):
  return object.get('swinging') != null and not object.swinging

## mandatory options: {propertyPath, toValue}
static func swing(object, _options):
  var options = _options.duplicate()

  if(_stoppedSwinging(object)):
    return

  # --------
  # swing forth

  options.fromValue = __.Get(options.propertyPath, object)
  options.signalToWait = 'swing1Done'

  _animate(object, options)
  await Signal(object, 'swing1Done')

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
  await Signal(object, 'swing2Done')

  if(_stoppedSwinging(object)):
    return

  # --------
  # loop

  swing(object, _options)

# ------------------------------------------------------------------------------

static func _animate(object, options):
  if(not object):
    G.log('warning: trying to Animate a Nil object', options);
    return

  if(typeof(object) != TYPE_OBJECT):
    prints(
      '🔴 Animate is meant for TYPE_OBJECT, not',
      typeof(object),
      'https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-variant-type'
    )
    return

  var propertyPath = options.propertyPath
  var toValue = options.get('toValue')

  var delay = __.GetOr(0, 'delay', options)
  var duration = __.GetOr(0.75, 'duration', options)
  var easing = __.GetOr(Tween.EASE_OUT, 'easing', options)

  var transition = options.transition if options.get('transition') else Tween.TRANS_QUAD

  # --------

  var SIGNAL_ON_DONE = options.signalToWait if options.get('signalToWait') else ANIMATION_DONE

  if(not object.has_signal(SIGNAL_ON_DONE)):
    object.add_user_signal(SIGNAL_ON_DONE)

  # --------

  var fields = Array(propertyPath.split('.'))
  var property = fields.pop_back()

  # --------

  var nestedToAnimate = object
  if(fields.size() > 0):
    var nestedPath = '.'.join(PackedStringArray(fields))
    nestedToAnimate = __.Get(nestedPath, object)

  # --------

  if(delay > 0):
    await Wait.forSomeTime(object, delay).timeout

  # --------

  var tween = object.create_tween()

  tween.tween_property(nestedToAnimate, property, toValue, duration).set_trans(transition).set_ease(easing)

  tween.connect("finished", func onFinished():
    object.emit_signal(SIGNAL_ON_DONE)

    if(options.get('onFinished')):
      options.onFinished.call()
  )
