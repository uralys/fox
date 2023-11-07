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

var dragging = false
var pressing = false
var lastPress = Time.get_ticks_msec()

# ------------------------------------------------------------------------------

signal dragged
signal startedDragging

# ------------------------------------------------------------------------------

func _ready():
  connect('gui_input' , _gui_input)
  params.id = generateUID.withPrefix('draggable')

# ------------------------------------------------------------------------------

func _physics_process(_delta):
  if(useManualDragStart or !afterLongPress):
    return

  if pressing:
    var now = Time.get_ticks_msec()
    var elapsedTime = now - lastPress

    if(elapsedTime > timeBeforeDragging):
      var mousePosition = get_global_mouse_position()
      pressing = false

      if(abs(mouseStartPosition - mousePosition).length() > 1):
        return

      startDragging()

# ------------------------------------------------------------------------------

func startDragging():
  G.log('startDragging');
  dragging = true
  Display.DRAGGING_OBJECT = params.id
  screenStartPosition = draggable.position
  emit_signal('startedDragging')

# ------------------------------------------------------------------------------

func _gui_input(event):
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
    lastPress = Time.get_ticks_msec()
    mouseStartPosition = get_global_mouse_position()

    if(not afterLongPress and not useManualDragStart):
      startDragging()
    else:
      pressing = true

    return

  if event is InputEventMouseButton \
  and event.button_index == MOUSE_BUTTON_LEFT \
  and !event.pressed:
    if(dragging):
      emit_signal('dragged', draggable.position)

    Display.DRAGGING_OBJECT = null
    dragging = false
    pressing = false
    return

  if dragging \
  and event is InputEventMouseMotion \
  and Display.DRAGGING_OBJECT == params.id:
    var mouseDiff = get_global_mouse_position() - mouseStartPosition
    draggable.position = mouseDiff / zoom + screenStartPosition
