extends Control

# ------------------------------------------------------------------------------

var draggable
var zoom = 1
var params = {}
var mouseStartPosition
var screenStartPosition

@export var afterLongPress: bool = false
@export var useManualDragStart: bool = false
@export var timeBeforeDragging: int = 500

var _dragging = false
var _pressing = false

var isPressing = false
var isLongPressing = false
var lastPress = Time.get_ticks_msec()

# ------------------------------------------------------------------------------

signal press
signal pressing
signal longPress

signal dragged
signal startedDragging

# ------------------------------------------------------------------------------

func _ready():
  params.id = generateUID.withPrefix('draggable')

# ------------------------------------------------------------------------------

func _physics_process(_delta):
  if _pressing:
    var now = Time.get_ticks_msec()
    var elapsedTime = now - lastPress

    if(not isPressing and elapsedTime > 150):
      emit_signal('pressing')
      isPressing = true

    if(not isLongPressing and elapsedTime > timeBeforeDragging):
      isLongPressing = true
      emit_signal('longPress')

      if(draggable and afterLongPress and !useManualDragStart):
        var mousePosition = get_global_mouse_position()

        if((mouseStartPosition - mousePosition).length() < 50):
          return

        startDragging()

# ------------------------------------------------------------------------------

func startDragging():
  if(not draggable):
    G.log('[color=pink]You must set your draggable object before to use dragging.[/color]')
    return

  _dragging = true
  Display.DRAGGING_OBJECT = params.id
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

    if(draggable and not afterLongPress and not useManualDragStart):
      startDragging()
    else:
      _pressing = true

    return

  # ---------- mouse up ----------
  if event is InputEventMouseButton \
  and event.button_index == MOUSE_BUTTON_LEFT \
  and !event.pressed:
    if(_dragging):
      emit_signal('dragged', draggable.position)
    else:
      emit_signal('press')

    Display.DRAGGING_OBJECT = null
    _dragging = false
    _pressing = false
    isPressing = false

    return

  # ---------- mouse move ----------
  if _dragging \
  and event is InputEventMouseMotion \
  and Display.DRAGGING_OBJECT == params.id:
    var mouseDiff = get_global_mouse_position() - mouseStartPosition
    draggable.position = mouseDiff / zoom + screenStartPosition
