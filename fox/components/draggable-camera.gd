extends Camera2D

# ------------------------------------------------------------------------------

var mouse_start_pos
var screen_start_position

var dragging = false
var moving = false

# ------------------------------------------------------------------------------

export(float) var pan_smooth := -5

# ------------------------------------------------------------------------------

var _cur_vel := Vector2(0,0)
var _last_cam_pos := Vector2(0,0)

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

# ------------------------------------------------------------------------------

func _process(delta):
	if delta <= 0:
		return

	if dragging:
		update_vel(delta)
	else:
		smooth(delta)

	var diff= _last_cam_pos - self.position
	moving = diff.length() > 1

	_last_cam_pos = self.position

# ------------------------------------------------------------------------------

func update_vel(delta : float):
	var move = _last_cam_pos - self.position
	var move_speed:Vector2 = move / delta
	_cur_vel = (_cur_vel + move_speed) / 2.0
	_cur_vel.x = clamp(_cur_vel.x, -10000, 10000)
	_cur_vel.y = clamp(_cur_vel.y, -10000, 10000)

# ------------------------------------------------------------------------------

func smooth(delta : float):
	var l = _cur_vel.length()
	var move_frame = 10 * exp(pan_smooth * ((log(l/10) / pan_smooth)+delta))
	_cur_vel = _cur_vel.normalized() * move_frame
	self.position -= _cur_vel * delta
