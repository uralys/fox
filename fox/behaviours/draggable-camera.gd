# ------------------------------------------------------------------------------
# tips from
# https://github.com/Ombarus/SolarRogue/blob/master/scripts/CamControl.gd
# https://www.youtube.com/watch?v=duDk9ICkKWI
# ------------------------------------------------------------------------------

extends Camera2D

# ------------------------------------------------------------------------------

var tween
var boundaries

var mouse_start_pos
var screen_start_position

var tweening = false
var pressing = false
var dragging = false
var smoothing = false
var moving = false
var startPressingTime = 0

# ------------------------------------------------------------------------------

@export var pan_smooth: float = -5
@export var drag_delay: float = 120

# ------------------------------------------------------------------------------

var draggingVelocity := Vector2(0,0)
var _last_cam_pos := Vector2(0,0)

# ------------------------------------------------------------------------------

func _ready():
  tween = Tween.new()
  add_child(tween)

  if(get_parent().has_node('boundaries')):
    boundaries = get_parent().get_node('boundaries')

# ------------------------------------------------------------------------------

func _input(event):
  if event is InputEventMouseButton:
    if event.is_pressed():
      var now = Time.get_ticks_msec()
      startPressingTime = now
      tween.stop(self, 'position')
      tweening = false
      smoothing = false
      pressing = true

    else:
      pressing = false
      dragging = false
      startPressingTime = 0

      if(boundaries):
        var outOfBoundaries = checkBoundaries({reposition=true})
        if(not outOfBoundaries):
          smoothing = true

  elif event is InputEventMouseMotion:
    if(startPressingTime > 0):
      var now = Time.get_ticks_msec()
      if(now - startPressingTime > drag_delay):
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
  elif smoothing:
    smooth(delta)

  var diff = _last_cam_pos - self.position
  moving = diff.length() > 5
  _last_cam_pos = self.position

  if(not moving and not pressing):
    smoothing = false
    tweening = false

    if(boundaries):
      checkBoundaries({reposition=true})

# ------------------------------------------------------------------------------

func update_vel(delta : float):
  var move = _last_cam_pos - self.position
  var move_speed:Vector2 = move / delta
  draggingVelocity = (draggingVelocity + move_speed) / 2.0
  draggingVelocity.x = clamp(draggingVelocity.x, -10000, 10000)
  draggingVelocity.y = clamp(draggingVelocity.y, -10000, 10000)

# ------------------------------------------------------------------------------

func toPosition(from: Vector2, to : Vector2, duration: float = 1):
  if(smoothing or tweening or dragging):
    return

  tweening = true
  tween.interpolate_property(
    self,
    'position',
    from, to,
    duration,
    Tween.TRANS_QUAD, Tween.EASE_OUT
  )

  tween.start()


  await tween.finished
  tweening = false

# ------------------------------------------------------------------------------

func smooth(delta : float):
  if(tweening):
    return

  # cancel smoothing if going out of boundaries
  if(boundaries):
    var outOfBoundaries = checkBoundaries({offset=400})
    if(outOfBoundaries):
      smoothing = false
      return

  var l = draggingVelocity.length()
  var move_frame = 10 * exp(pan_smooth * ((log(l/10) / pan_smooth)+delta))
  draggingVelocity = draggingVelocity.normalized() * move_frame
  self.position -= draggingVelocity * delta

# ------------------------------------------------------------------------------

func checkBoundaries(options = {}):
  var reposition = options.reposition if options.has('reposition') else false
  var _offset = options.offset if options.has('offset') else 0

  var boundariesLeft = boundaries.position.x - _offset
  var boundariesRight = boundaries.position.x + boundaries.size[0] + _offset
  var boundariesTop = boundaries.position.y - _offset
  var boundariesBottom = boundaries.position.y + boundaries.size[1] + _offset

  var outOnLeft = position.x < boundariesLeft
  var outOnRight = position.x > boundariesRight
  var outOnTop = position.y < boundariesTop
  var outOnBottom = position.y > boundariesBottom

  if outOnLeft or outOnRight or outOnBottom or outOnTop:
    if(reposition):
      var newX = position.x
      var newY = position.y
      var innerMargin = 10 # not to have accurate equalities

      if outOnLeft:
        newX = boundariesLeft + innerMargin
      if outOnRight:
        newX = boundariesRight - innerMargin
      if outOnTop:
        newY = boundariesTop + innerMargin
      if outOnBottom:
        newY = boundariesBottom - innerMargin

      if(newX != position.x or newY != position.y):
        toPosition(position, Vector2(newX, newY), 0.5)

    return true
