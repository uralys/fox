extends Control

# ------------------------------------------------------------------------------

var draggable
var params = {}
var mouseStartPosition
var screenStartPosition

@export var afterLongPress: bool = false

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
  if(!afterLongPress):
    return

  if pressing:
    var now = Time.get_ticks_msec()
    var elapsedTime = now - lastPress

    if(elapsedTime > 500):
      var mousePosition = get_global_mouse_position()
      pressing = false

      if(abs(mouseStartPosition - mousePosition).length() > 1):
        return

      emit_signal('startedDragging')
      startDragging()

# ------------------------------------------------------------------------------

func startDragging():
  dragging = true
  Display.DRAGGING_OBJECT = params.id
  screenStartPosition = draggable.position

# ------------------------------------------------------------------------------

func _gui_input(event):
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
    lastPress = Time.get_ticks_msec()
    mouseStartPosition = get_global_mouse_position()

    if(not afterLongPress):
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
    draggable.position = (get_global_mouse_position() - mouseStartPosition) + screenStartPosition
