extends Control

# ------------------------------------------------------------------------------

var draggable
var zoom = 1
var params = {}
var mouseStartPosition
var screenStartPosition

@export var minDragTime: int = 20
@export var minPressTime: int = 150
@export var longPressTime: int = 500

@export var dragAfterLongPress: bool = false
@export var useManualDragStart: bool = false

var _dragging = false
var _pressing = false

var isPressing = false
var isLongPressing = false
var lastPress = Time.get_ticks_msec()

# ------------------------------------------------------------------------------

signal press
signal pressing
signal longPress

signal dropped
signal startedDragging

# ------------------------------------------------------------------------------

func _physics_process(_delta):
  if _pressing:
    var now = Time.get_ticks_msec()
    var elapsedTime = now - lastPress
    var mousePosition = get_global_mouse_position()

    var mouseDiff = mouseStartPosition - mousePosition
    var minMouseDragTresholdReached = (mouseDiff).length() > 3

    if(draggable \
      and not _dragging
      and minMouseDragTresholdReached \
      and not dragAfterLongPress \
      and not useManualDragStart \
      and elapsedTime > minDragTime):
      startDragging()

    if(not isPressing and elapsedTime > minPressTime):
      emit_signal('pressing')
      isPressing = true

    if(not isLongPressing and elapsedTime > longPressTime):
      isLongPressing = true
      emit_signal('longPress')

      if(draggable \
        and not _dragging
        and minMouseDragTresholdReached \
        and dragAfterLongPress \
        and not useManualDragStart):
        startDragging()

# ------------------------------------------------------------------------------

func startDragging():
  if(not draggable):
    G.log('[color=pink]You must set your draggable object before to use dragging.[/color]')
    return

  _dragging = true
  G.state.DRAGGING_OBJECT = draggable
  screenStartPosition = draggable.position
  emit_signal('startedDragging')

# ------------------------------------------------------------------------------

func _gui_input(event):
  # ---------- mouse down ----------
  if event is InputEventMouseButton \
  and event.button_index == MOUSE_BUTTON_LEFT \
  and event.pressed:
    lastPress = Time.get_ticks_msec()
    mouseStartPosition = get_global_mouse_position()
    _pressing = true

    return

  # ---------- mouse up ----------
  if event is InputEventMouseButton \
  and event.button_index == MOUSE_BUTTON_LEFT \
  and !event.pressed:
    if(_dragging):
      emit_signal('dropped', draggable.position)
      G.state.DRAGGING_OBJECT = null
    else:
      emit_signal('press')

    _dragging = false
    _pressing = false
    isPressing = false

    return

  # ---------- mouse move ----------
  if _dragging \
  and event is InputEventMouseMotion:
    var mouseDiff = get_global_mouse_position() - mouseStartPosition
    draggable.position = mouseDiff / zoom + screenStartPosition
