extends Tween

# ------------------------------------------------------------------------------

var nextAnimation

# ------------------------------------------------------------------------------

func _ready():
  connect('finished',Callable(self,'onAnimationfinished'))

# ------------------------------------------------------------------------------

func animateFrames(
  fromFrame: int,
  toFrame: int,
  reverse: bool = false,
  maxNbFrames: int = 0,
  _totalDuration = 0.3,
  _duration = null,
  # delay = 0
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
  # 🏗️ note as of refacting with Godot4: Tween is no longer a Node
  # get_parent() is irrelevant; there is surely a better way to do implement this frame animation
  # unplugging this for now / lockey land is not working anymore with this update.

  # if(is_running()):
  #   stop(get_parent(), 'frame')

  # # -----------

  # interpolate_property(
  #   get_parent(),
  #   'frame',
  #   from, to,
  #   duration,
  #   Tween.TRANS_LINEAR, Tween.EASE_OUT,
  #   delay
  # )

  play()

# ------------------------------------------------------------------------------

func onAnimationfinished(_object, _key):
  if(nextAnimation):
    animateFrames(
      nextAnimation.from,
      nextAnimation.to,
      nextAnimation.reverse,
      nextAnimation.maxNbFrames,
      nextAnimation.duration
    )
