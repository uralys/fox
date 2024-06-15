extends Area2D

@onready var collisionShape = $CollisionShape2D

@export var fullscreen:bool = false

# ------------------------------------------------------------------------------

signal pressed
signal pressing
signal dragging
signal stopPressing
signal longPress

# ------------------------------------------------------------------------------

@export var longPressTime: int = 500

# ------------------------------------------------------------------------------

var lastPress = Time.get_ticks_msec()
var latestPressEvent

# ------------------------------------------------------------------------------

var _pressing = false
var isLongPressing = false

# ------------------------------------------------------------------------------

func _ready():
  if(fullscreen):
    fillScreenDimensions()
    $/root.connect('size_changed', fillScreenDimensions)

func fillScreenDimensions():
  collisionShape.shape.size = Vector2(G.W, G.H)
  collisionShape.position = Vector2(G.W / 2.0, G.H / 2.0)

# ------------------------------------------------------------------------------

func formatEvent(event):
  return {
    position = __.Get('position', event),
    pressed = __.Get('pressed', event),
    index = __.GetOr(__.Get('button_index', event), 'index', event)
  }

# ------------------------------------------------------------------------------

func _input(_event):
  var event = formatEvent(_event)

  if _event is InputEventMouseButton \
  and _event.button_index == MOUSE_BUTTON_LEFT:
    if(event.pressed):
      emit_signal('pressing', event)
      lastPress = Time.get_ticks_msec()
      latestPressEvent = event
    else:
      isLongPressing = false
      emit_signal('pressed', event)
      emit_signal('stopPressing', event)

    _pressing = event.pressed

  elif _event is InputEventScreenTouch:
    if(event.pressed):
      emit_signal('pressing', event)
      lastPress = Time.get_ticks_msec()
      latestPressEvent = event
    else:
      isLongPressing = false
      emit_signal('pressed', event)
      emit_signal('stopPressing', event)

  elif(_event is InputEventMouseMotion):
    if(_pressing):
      emit_signal('dragging', event)

  elif(_event is InputEventScreenDrag):
    if(_pressing):
      emit_signal('dragging', event)

  else:
    G.debug('⚡ event:', _event)

# ------------------------------------------------------------------------------

func _physics_process(_delta):
  if _pressing:
    var now = Time.get_ticks_msec()
    var elapsedTime = now - lastPress

    if(not isLongPressing and elapsedTime > longPressTime):
      isLongPressing = true
      emit_signal('longPress', latestPressEvent)
