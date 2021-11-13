extends Camera2D

# ------------------------------------------------------------------------------

var tween
var mouse_start_pos
var screen_start_position

var tweening = false
var dragging = false
var moving = false
var startPressingTime = 0

# ------------------------------------------------------------------------------

export(float) var pan_smooth := -5

# ------------------------------------------------------------------------------

var draggingVelocity := Vector2(0,0)
var _last_cam_pos := Vector2(0,0)

# ------------------------------------------------------------------------------

func _ready():
  tween = Tween.new()
  add_child(tween)

# ------------------------------------------------------------------------------

func _input(event):
  if event is InputEventMouseButton:
    if event.is_pressed():
      var now = OS.get_ticks_msec()
      startPressingTime = now

    else:
      dragging = false
      startPressingTime = 0

  elif event is InputEventMouseMotion:
    if(startPressingTime > 0):
      var now = OS.get_ticks_msec()
      if(now - startPressingTime > 120):
        if(not dragging):
          dragging = true
          mouse_start_pos = event.position
          screen_start_position = position

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
  draggingVelocity = (draggingVelocity + move_speed) / 2.0
  draggingVelocity.x = clamp(draggingVelocity.x, -10000, 10000)
  draggingVelocity.y = clamp(draggingVelocity.y, -10000, 10000)

# ------------------------------------------------------------------------------

func toPosition(from: Vector2, to : Vector2):
  tween.interpolate_property(
    self,
    'position',
    from, to,
    1,
    Tween.TRANS_QUAD, Tween.EASE_OUT
  )

  tween.start()

# ------------------------------------------------------------------------------

func smooth(delta : float):
  if(tweening):
    return

  var l = draggingVelocity.length()
  var move_frame = 10 * exp(pan_smooth * ((log(l/10) / pan_smooth)+delta))
  draggingVelocity = draggingVelocity.normalized() * move_frame
  self.position -= draggingVelocity * delta
