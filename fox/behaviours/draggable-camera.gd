# ------------------------------------------------------------------------------
# tips from
# https://github.com/Ombarus/SolarRogue/blob/master/scripts/CamControl.gd
# https://www.youtube.com/watch?v=duDk9ICkKWI
# ------------------------------------------------------------------------------

extends Camera2D

# ------------------------------------------------------------------------------

const Gesture = preload("res://fox/libs/gesture.gd")

@onready var camera = self
@onready var boundaries = _resolveBoundaries()

func _resolveBoundaries():
  var node = get_node_or_null("boundaries")
  if node == null:
    node = get_node_or_null("../boundaries")
  if node and node is Control:
    node.visible = false
  return node

# ------------------------------------------------------------------------------

signal startPressing
signal startDragging
signal stopDragging
signal draggingCamera

# ------------------------------------------------------------------------------

@export var pan_smooth: float = -1
@export var dragDelay: float = 30
@export var dragDistanceThreshold: float = 15

# ------------------------------------------------------------------------------

var ZOOM = 2.5

var mouse_start_pos
var screen_start_position

var tweening = false
var pressing = false
var dragging = false
var dragged = false
var smoothing = false
var moving = false
var startPressingTime = 0
var startPressingPosition

# ------------------------------------------------------------------------------

var draggingVelocity := Vector2(0,0)
var _last_cam_pos := Vector2(0,0)
var _activeTween: Tween = null

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
      _killActiveTween()
      tweening = false
      smoothing = false
      draggingVelocity = Vector2.ZERO
      pressing = true
      dragged = false
      startPressing.emit()

    # ------- mouse up
    else:
      pressing = false
      startPressingTime = 0
      startPressingPosition = null

      if(Gesture.isDragging()):
        return

      if(dragging):
        dragging = false
        stopDragging.emit()

        var outOfBoundaries = false
        if(boundaries):
          outOfBoundaries = checkBoundaries({reposition=true})

        if(not outOfBoundaries):
          smoothing = true

  # ------- mouse mmotion
  elif event is InputEventMouseMotion:
    # updates position only when global dragging is occuring
    if(Gesture.isDragging()):
      return

    if(startPressingTime > 0):
      var now = Time.get_ticks_msec()
      if(now - startPressingTime > dragDelay):
        var startDiff = startPressingPosition - event.position
        if(startDiff.length() < dragDistanceThreshold):
          return

        if(not dragging):
          dragging = true
          dragged = true
          _killActiveTween()
          tweening = false
          smoothing = false
          mouse_start_pos = event.position
          screen_start_position = camera.position
          startDragging.emit()

        var mouseDiff = mouse_start_pos - event.position
        camera.position = mouseDiff / ZOOM + screen_start_position
        draggingCamera.emit()
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

  # don't decay velocity on idle frames; preserve last-known momentum
  if move.length() < 1:
    return

  var move_speed:Vector2 = move / delta

  draggingVelocity = (draggingVelocity + move_speed  ) / 2.0
  draggingVelocity.x = clamp(draggingVelocity.x, -10000, 10000)
  draggingVelocity.y = clamp(draggingVelocity.y, -10000, 10000)

# ------------------------------------------------------------------------------

func toPosition(from: Vector2, to : Vector2, duration: float = 1):
  if(smoothing or tweening or dragging):
    return

  tweening = true

  _killActiveTween()
  _activeTween = create_tween()

  camera.position = from
  _activeTween.tween_property(camera, "position", to, duration).connect("finished", func():
    tweening = false
    _activeTween = null
  )

# ------------------------------------------------------------------------------

func _killActiveTween():
  if _activeTween and _activeTween.is_valid():
    _activeTween.kill()
  _activeTween = null

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
  if(l < 10):
    smoothing = false
    draggingVelocity = Vector2.ZERO
    return

  var move_frame = 10 * exp(pan_smooth * ((log(l/10) / pan_smooth)+delta))
  draggingVelocity = draggingVelocity.normalized() * move_frame
  camera.position -= draggingVelocity * delta

# ------------------------------------------------------------------------------

func checkBoundaries(options = {}):
  var reposition = options.reposition if options.has('reposition') else false
  var _offset = options.offset if options.has('offset') else 0

  # inset by half viewport / zoom so viewport edges stay within the rect
  var halfView = get_viewport_rect().size / (2.0 * camera.zoom.x)

  var rectLeft = boundaries.position.x
  var rectRight = boundaries.position.x + boundaries.size.x
  var rectTop = boundaries.position.y
  var rectBottom = boundaries.position.y + boundaries.size.y

  var boundariesLeft = rectLeft + halfView.x - _offset
  var boundariesRight = rectRight - halfView.x + _offset
  var boundariesTop = rectTop + halfView.y - _offset
  var boundariesBottom = rectBottom - halfView.y + _offset

  # if the rect is smaller than the viewport on an axis, keep camera centered on it
  if boundariesLeft > boundariesRight:
    var cx = (rectLeft + rectRight) / 2.0
    boundariesLeft = cx
    boundariesRight = cx
  if boundariesTop > boundariesBottom:
    var cy = (rectTop + rectBottom) / 2.0
    boundariesTop = cy
    boundariesBottom = cy

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

func setZoom(_zoom: float):
  ZOOM = _zoom
  camera.zoom = Vector2(_zoom, _zoom)

func zoomIn():
  camera.zoom = Vector2(ZOOM * 0.7, ZOOM * 0.7)

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
