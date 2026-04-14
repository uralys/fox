extends Node

# ------------------------------------------------------------------------------

var nextAnimation
var _tween: Tween

# ------------------------------------------------------------------------------

func _ready():
  pass

# ------------------------------------------------------------------------------

func animateFrames(
  fromFrame: int,
  toFrame: int,
  reverse: bool = false,
  maxNbFrames: int = 0,
  _totalDuration = 0.3,
  _duration = null,
):

  nextAnimation = null
  var from = fromFrame
  var to = toFrame
  var nbFrames = abs(toFrame - fromFrame)

  # queueing fromFrame -> 32 and 0 -> toFrame -------------
  if((not reverse) and maxNbFrames and fromFrame > toFrame):
    to = maxNbFrames - 1
    nbFrames = abs(toFrame + maxNbFrames - fromFrame)
    nextAnimation = {
      from = 0,
    }

  # queueing fromFrame -> 0 and 32 -> toFrame ------------
  if(reverse and maxNbFrames and toFrame > fromFrame):
    to = 0
    nbFrames = abs(toFrame + maxNbFrames - fromFrame)
    nextAnimation = {
      from = maxNbFrames - 1,
    }

  # -----------

  var duration = _duration

  if(not _duration):
    if(nbFrames == 0):
      duration = 0
    else:
      duration = _totalDuration * abs(to - from) / nbFrames

  # -----------

  if(nextAnimation):
    nextAnimation.to = toFrame
    nextAnimation.reverse = reverse
    nextAnimation.maxNbFrames = maxNbFrames
    nextAnimation.duration = _totalDuration - duration
    nextAnimation.totalDuration = _totalDuration

  # -----------

  if _tween and _tween.is_running():
    _tween.kill()

  var sprite = get_parent()
  sprite.frame = from

  if duration <= 0:
    sprite.frame = to
    _onAnimationFinished()
    return

  _tween = sprite.create_tween()
  _tween.tween_property(
    sprite,
    'frame',
    to,
    duration
  ).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)

  _tween.finished.connect(_onAnimationFinished)

# ------------------------------------------------------------------------------

func _onAnimationFinished():
  if(nextAnimation):
    animateFrames(
      nextAnimation.from,
      nextAnimation.to,
      nextAnimation.reverse,
      nextAnimation.maxNbFrames,
      nextAnimation.duration
    )
