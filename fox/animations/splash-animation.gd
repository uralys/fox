extends Node

# ------------------------------------------------------------------------------

signal splashFinished

# ------------------------------------------------------------------------------

const STEP_DURATION = 0.75
var blurring = false

# ------------------------------------------------------------------------------

@onready var blur = $blur
@onready var bg = $bg
@onready var logo = $logo
@onready var letters = $letters

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
  prints('> splashScreen');
  prints('-------------------------------')
  var appearDuration = 0.75
  var appearDelay = 0.2

  letters.hide()
  Animate.show(logo, 2)

  blur.material.set_shader_parameter('blur_amount', 0)

  await Wait.forSomeTime(self, 0.6).timeout
  letters.show()
  blurring = true

  Animate.show(U, appearDuration, appearDelay)
  Animate.show(R, appearDuration, appearDelay)
  Animate.show(A, appearDuration, appearDelay)
  Animate.show(L, appearDuration, appearDelay)
  Animate.show(Y, appearDuration, appearDelay)
  Animate.show(S, appearDuration, appearDelay)
  Animate.show(DOT, appearDuration, appearDelay)

  var delay = appearDuration + appearDelay + 0.1
  await Wait.forSomeTime(self, delay).timeout

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
  Animate.hide(S, STEP_DURATION, 0.7)
  Animate.hide(DOT, STEP_DURATION, .8)

  Animate.to(logo, {
    propertyPath = 'scale',
    toValue = Vector2(0.3, 0.3),
    duration = 4,
    easing = Tween.EASE_IN
  })

  await Signal(A, 'scaled')
  Animate.hide(A, 1.2, 0.3)
  Animate.hide(logo, 2)
  await Wait.forSomeTime(self, 1).timeout
  exitSplashAnimation()

# ------------------------------------------------------------------------------

func _physics_process(delta):
  if(blurring):
    var current = blur.material.get_shader_parameter('blur_amount')
    var newValue = current - delta * 15
    blur.material.set_shader_parameter('blur_amount', newValue)

# ------------------------------------------------------------------------------

func exitSplashAnimation():
  emit_signal('splashFinished')
  get_parent().remove_child(self)
  queue_free()
