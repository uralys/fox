extends Node

signal splashFinished

const STEP_DURATION = 2

# Called when the node enters the scene tree for the first time.
func _ready():
	var W = get_viewport().size.x
	var H = get_viewport().size.y
	var centerX = W/2
	var centerY = H/2

	# ------------------- UR

	Animate.hide($u, STEP_DURATION, 1.3)
	Animate.hide($r, STEP_DURATION, 0.8)

	# ------------------- A

	Animate.to($a, {
		propertyPath = 'position',
		toValue = Vector2(centerX, centerY),
		duration = STEP_DURATION + 2,
		easing = Tween.EASE_IN_OUT,
		delay = 0.3
	})

	Animate.to($a, {
		propertyPath = 'scale',
		toValue = $a.scale * 3,
		duration = STEP_DURATION + 2,
		easing = Tween.EASE_IN_OUT,
		delay = 0.3,
		signalToWait = 'scaled'
	})

	# ------------------- LYS.

	Animate.hide($l, STEP_DURATION, 0.5)
	Animate.hide($y, STEP_DURATION, 0.8)
	Animate.hide($s, STEP_DURATION, 0.2)
	Animate.hide($dot, STEP_DURATION, 1)

	yield($a, 'scaled')
	Animate.hide($a, 1.5, 0.5)

	var timer = Wait.start(self, 2)
	yield(timer, 'timeout')

	emit_signal('splashFinished')
	get_parent().remove_child(self)
	queue_free()

