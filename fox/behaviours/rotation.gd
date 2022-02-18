extends TextureRect

const TURN_DURATION = 1

func _process(delta):
	rect_rotation += 360 / float(TURN_DURATION) * delta
	pass
