# ------------------------------------------------------------------------------
# tips from
# https://github.com/Ombarus/SolarRogue/blob/master/scripts/CamControl.gd
# https://www.youtube.com/watch?v=duDk9ICkKWI
# ------------------------------------------------------------------------------

extends CanvasLayer

# ------------------------------------------------------------------------------

@onready var camera = $camera
@onready var boundaries = $boundaries

# ------------------------------------------------------------------------------

signal startPressing
signal startDragging
signal stopDragging
signal draggingCamera

# ------------------------------------------------------------------------------

@export var pan_smooth: float = -3
@export var dragDelay: float = 80

# ------------------------------------------------------------------------------

const ZOOM = 2.5

var mouse_start_pos
var screen_start_position

var tweening = false
var pressing = false
var dragging = false
var smoothing = false
var moving = false
var startPressingTime = 0
var startPressingPosition

# ------------------------------------------------------------------------------

var draggingVelocity := Vector2(0,0)
var _last_cam_pos := Vector2(0,0)

# ------------------------------------------------------------------------------

## it's not possible to create a local behaviour because a fullscreen Control
## for the camera would intercept all input events
func _input(event):
  if event is InputEventMouseButton:
    # ------- mouse down
    if event.is_pressed():
      var now = Time.get_ticks_msec()
      startPressingTime = now
      startPressingPosition = event.position
      tweening = false
      smoothing = false
      pressing = true
      emit_signal('startPressing')

    # ------- mouse up
    else:
      pressing = false
      startPressingTime = 0
      startPressingPosition = null

      if(G.state.DRAGGING_DATA != null):
        return

      if(dragging):
        dragging = false

        emit_signal('stopDragging')

        if(boundaries):
          var outOfBoundaries = checkBoundaries({reposition=true})
          if(not outOfBoundaries):
            smoothing = true

  # ------- mouse mmotion
  elif event is InputEventMouseMotion:
    # updates position only when global dragging is occuring
    if(G.state.DRAGGING_DATA != null):
      return

    if(startPressingTime > 0):
      var now = Time.get_ticks_msec()
      if(now - startPressingTime > dragDelay):
        var startDiff = startPressingPosition - event.position
        if(startDiff.length() < 50):
          return

        if(not dragging):
          dragging = true
          mouse_start_pos = event.position
          screen_start_position = camera.position

          emit_signal('startDragging')

        var mouseDiff = mouse_start_pos - event.position
        camera.position = mouseDiff / ZOOM + screen_start_position
        emit_signal('draggingCamera')
        get_viewport().set_input_as_handled()


# ------------------------------------------------------------------------------

func _process(delta):
  if delta <= 0:
    return

  if dragging:
    update_vel(delta)
  elif smoothing:
    smooth(delta)

  var diff = _last_cam_pos - camera.position
  moving = diff.length() > 5
  _last_cam_pos = camera.position

  if(not moving and not pressing):
    smoothing = false
    tweening = false

    if(boundaries):
      checkBoundaries({reposition=true})

# ------------------------------------------------------------------------------

func update_vel(delta : float):
  var move = _last_cam_pos - camera.position
  var move_speed:Vector2 = move / delta

  draggingVelocity = (draggingVelocity + move_speed  ) / 2.0
  draggingVelocity.x = clamp(draggingVelocity.x, -10000, 10000)
  draggingVelocity.y = clamp(draggingVelocity.y, -10000, 10000)

# ------------------------------------------------------------------------------

func toPosition(from: Vector2, to : Vector2, duration: float = 1):
  if(smoothing or tweening or dragging):
    return

  tweening = true

  var tween = create_tween()

  camera.position = from
  tween.tween_property(camera, "position", to, duration).connect("finished", func():
    tweening = false
  )

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
  camera.position -= draggingVelocity * delta

# ------------------------------------------------------------------------------

func checkBoundaries(options = {}):
  var reposition = options.reposition if options.has('reposition') else false
  var _offset = options.offset if options.has('offset') else 0

  var boundariesLeft = boundaries.position.x - _offset
  var boundariesRight = boundaries.position.x + boundaries.size[0] + _offset
  var boundariesTop = boundaries.position.y - _offset
  var boundariesBottom = boundaries.position.y + boundaries.size[1] + _offset

  var outOnLeft = camera.position.x < boundariesLeft
  var outOnRight = camera.position.x > boundariesRight
  var outOnTop = camera.position.y < boundariesTop
  var outOnBottom = camera.position.y > boundariesBottom

  if outOnLeft or outOnRight or outOnBottom or outOnTop:
    if(reposition):
      var newX = camera.position.x
      var newY = camera.position.y
      var innerMargin = 10 # not to have accurate equalities

      if outOnLeft:
        newX = boundariesLeft + innerMargin
      if outOnRight:
        newX = boundariesRight - innerMargin
      if outOnTop:
        newY = boundariesTop + innerMargin
      if outOnBottom:
        newY = boundariesBottom - innerMargin

      if(newX != camera.position.x or newY != camera.position.y):
        toPosition(camera.position, Vector2(newX, newY), 0.5)

    return true

# ==============================================================================
# API
# ==============================================================================

func setPosition(_position: Vector2):
  camera.position = _position

func setZoom(_zoom: Vector2):
  camera.zoom = _zoom

func zoom():
  setZoom(Vector2(1.6, 1.6))

  Animate.to(camera, {
    propertyPath = 'zoom',
    toValue = Vector2(ZOOM, ZOOM),
    duration = 1,
    easing = Tween.EASE_OUT
  })

func focusCameraOn(_position):
  Animate.to(camera, {
    propertyPath = 'position',
    toValue = _position,
    duration = 1,
    easing = Tween.EASE_OUT
  })
