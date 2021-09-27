extends Camera2D

# ------------------------------------------------------------------------------

var mouse_start_pos
var screen_start_position

var dragging = false

# ------------------------------------------------------------------------------

func _input(event):
	if event is InputEventMouseButton:
		if event.is_pressed():
			mouse_start_pos = event.position
			screen_start_position = position
			dragging = true
		else:
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		position = zoom * (mouse_start_pos - event.position) + screen_start_position
