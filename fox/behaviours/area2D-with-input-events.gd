extends Area2D

# ------------------------------------------------------------------------------

var draggable
var additionalDragData
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

signal droppedOnDroppable
signal droppedIntheWild
signal startedDragging

# ------------------------------------------------------------------------------

func _ready():
  connect("input_event", onInput)

# ------------------------------------------------------------------------------

func _physics_process(_delta):
  if _pressing:
    var now = Time.get_ticks_msec()
    var elapsedTime = now - lastPress
    var mousePosition = get_global_mouse_position()

    var mouseDiff = mousePosition - mouseStartPosition
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

    if(_dragging):
      var newPosition = mouseDiff / zoom + screenStartPosition
      draggable.position = lerp(draggable.position, newPosition, 25 * _delta)

# ------------------------------------------------------------------------------

func onInput(_viewport, event, _shape_idx):
  # ---------- mouse down ----------
  if event is InputEventMouseButton \
  and event.button_index == MOUSE_BUTTON_LEFT \
  and event.pressed:
    lastPress = Time.get_ticks_msec()
    mouseStartPosition = get_global_mouse_position()
    _pressing = true

    return

# ------------------------------------------------------------------------------

func startDragging():
  if(not draggable):
    G.log('[color=pink]You must set your draggable object before to use dragging.[/color]')
    return

  _dragging = true

  G.state.DRAGGING_DATA = {
    draggable = draggable
  }

  if(additionalDragData):
    for key in additionalDragData.keys():
      var value = additionalDragData[key]
      __.Set(value, key, G.state.DRAGGING_DATA)

  screenStartPosition = draggable.position
  emit_signal('startedDragging')

# ------------------------------------------------------------------------------

func _unhandled_input(event):
  if _pressing \
    and event is InputEventMouseButton \
    and event.button_index == MOUSE_BUTTON_LEFT \
    and !event.pressed:

    if(_dragging):
      var droppable = __.Get('droppable', G.state.DRAGGING_DATA)
      if(droppable):
        droppable.onDrop(G.state.DRAGGING_DATA)
        emit_signal('droppedOnDroppable', droppable)
      else:
        emit_signal('droppedIntheWild', draggable.position)
      G.state.DRAGGING_DATA = null
    else:
      emit_signal('press')

    _dragging = false
    _pressing = false
    isPressing = false
