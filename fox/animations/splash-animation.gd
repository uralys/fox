extends Node

# ------------------------------------------------------------------------------

signal splashFinished

# ------------------------------------------------------------------------------

const STEP_DURATION = 0.75

# ------------------------------------------------------------------------------

@onready var U = $letters/u
@onready var R = $letters/r
@onready var A = $letters/a
@onready var L = $letters/l
@onready var Y = $letters/y
@onready var S = $letters/s
@onready var DOT = $letters/dot

# ------------------------------------------------------------------------------

# Called when the node enters the scene tree for the first time.
func _ready():
  if(DEBUG.NO_SPLASH_ANIMATION):
    exitSplashAnimation(0.1)
    return

  prints('> splashScreen');
  prints('-------------------------------')
  var appearDuration = 0.4
  var appearDelay = 0.1

  Animate.show(U, appearDuration, appearDelay)
  Animate.show(R, appearDuration, appearDelay)
  Animate.show(A, appearDuration, appearDelay)
  Animate.show(L, appearDuration, appearDelay)
  Animate.show(Y, appearDuration, appearDelay)
  Animate.show(S, appearDuration, appearDelay)
  Animate.show(DOT, appearDuration, appearDelay)

  var timer = Wait.start(Callable(self,appearDuration + appearDelay + 0.1))
  await timer.timeout

  # ------------------- UR

  Animate.hide(U, STEP_DURATION, .6)
  Animate.hide(R, STEP_DURATION, .2)

  # ------------------- A

  Animate.to(A, {
    propertyPath = 'position',
    toValue = Vector2(
      A.get_parent().size.x * 0.5,
      A.get_parent().size.y * 0.5
    ),
    duration = STEP_DURATION + 1,
    easing = Tween.EASE_IN_OUT,
    delay = 0.3
  })

  Animate.to(A, {
    propertyPath = 'scale',
    toValue = A.scale * 3,
    duration = STEP_DURATION + 1,
    easing = Tween.EASE_IN_OUT,
    delay = 0.3,
    signalToWait = 'scaled'
  })

  # ------------------- LYS.

  Animate.hide(L, STEP_DURATION, 0.5)
  Animate.hide(Y, STEP_DURATION, .3)
  Animate.hide(S, STEP_DURATION, 1.2)
  Animate.hide(DOT, STEP_DURATION, .8)

  await A.scaled
  Animate.hide(A, 0.5, 0.25)

  exitSplashAnimation(1)

# ------------------------------------------------------------------------------

func exitSplashAnimation(delay):
  var timer = Wait.start(Callable(self,delay))
  await timer.timeout

  emit_signal('splashFinished')
  get_parent().remove_child(self)
  queue_free()
