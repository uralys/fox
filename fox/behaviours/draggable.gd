extends Control

# ------------------------------------------------------------------------------

var parent = false
var params = {}
var mouseStartPosition
var screenStartPosition

# ------------------------------------------------------------------------------

signal dragged

# ------------------------------------------------------------------------------

func _ready():
  connect('gui_input' , _gui_input)
  params.id = generateUID.withPrefix('draggable')
  parent = get_parent();
  parent.add_user_signal('dragged')

# ------------------------------------------------------------------------------

func _gui_input(event):
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
    Display.DRAGGING_OBJECT = params.id
    mouseStartPosition = get_global_mouse_position()
    screenStartPosition = parent.position
    return

  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and !event.pressed:
    Display.DRAGGING_OBJECT = null
    return

  if event is InputEventMouseMotion and Display.DRAGGING_OBJECT == params.id:
    parent.position = (get_global_mouse_position()- mouseStartPosition) + screenStartPosition

    Wait.withTimer(0.3, self, func():
      parent.emit_signal('dragged', parent.position)
    )
