extends Node

# ------------------------------------------------------------------------------

signal splashFinished

# ------------------------------------------------------------------------------

const STEP_DURATION = 2

# ------------------------------------------------------------------------------

onready var U = $letters/u
onready var R = $letters/r
onready var A = $letters/a
onready var L = $letters/l
onready var Y = $letters/y
onready var S = $letters/s
onready var DOT = $letters/dot

# ------------------------------------------------------------------------------

# Called when the node enters the scene tree for the first time.
func _ready():
  if(DEBUG.NO_SPLASH_ANIMATION):
    exitSplashAnimation(0.1)
    return

  prints('> splashScreen');
  prints('-------------------------------')
  # ------------------- UR

  Animate.hide(U, STEP_DURATION, 1.6)
  Animate.hide(R, STEP_DURATION, 1.2)

  # ------------------- A

  Animate.to(A, {
    propertyPath = 'position',
    toValue = Vector2(
      A.get_parent().rect_size.x * 0.5,
      A.get_parent().rect_size.y * 0.5
    ),
    duration = STEP_DURATION + 2,
    easing = Tween.EASE_IN_OUT,
    delay = 0.3
  })

  Animate.to(A, {
    propertyPath = 'scale',
    toValue = A.scale * 3,
    duration = STEP_DURATION + 2,
    easing = Tween.EASE_IN_OUT,
    delay = 0.3,
    signalToWait = 'scaled'
  })

  # ------------------- LYS.

  Animate.hide(L, STEP_DURATION, 0.5)
  Animate.hide(Y, STEP_DURATION, 2.1)
  Animate.hide(S, STEP_DURATION, 1.2)
  Animate.hide(DOT, STEP_DURATION, 2.8)

  yield(A, 'scaled')
  Animate.hide(A, 1.5, 0.5)

  exitSplashAnimation(2)

# ------------------------------------------------------------------------------

func exitSplashAnimation(delay):
  var timer = Wait.start(self, delay)
  yield(timer, 'timeout')

  emit_signal('splashFinished')
  get_parent().remove_child(self)
  queue_free()
