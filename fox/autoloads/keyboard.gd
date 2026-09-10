extends Node

# ------------------------------------------------------------------------------

signal direction_up
signal direction_down
signal direction_left
signal direction_right
signal confirm
signal cancel

# ------------------------------------------------------------------------------

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP, KEY_W:
				direction_up.emit()
			KEY_DOWN, KEY_S:
				direction_down.emit()
			KEY_LEFT, KEY_A:
				direction_left.emit()
			KEY_RIGHT, KEY_D:
				direction_right.emit()
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				confirm.emit()
			KEY_ESCAPE:
				cancel.emit()
		return

	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_UP:
				direction_up.emit()
			JOY_BUTTON_DPAD_DOWN:
				direction_down.emit()
			JOY_BUTTON_DPAD_LEFT:
				direction_left.emit()
			JOY_BUTTON_DPAD_RIGHT:
				direction_right.emit()
			JOY_BUTTON_A:
				confirm.emit()
			JOY_BUTTON_B:
				cancel.emit()
