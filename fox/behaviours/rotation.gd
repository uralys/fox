extends TextureRect

const TURN_DURATION = 1

func _process(delta):
	rotation += 360 / float(TURN_DURATION) * delta
	pass
