extends Node

var dragging = false
var mouseStartPosition
var screenStartPosition

func _gui_input(event):
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
    dragging = true
    mouseStartPosition = event.position
    screenStartPosition = self.position
    return

  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and !event.pressed:
    dragging = false
    return

  if event is InputEventMouseMotion and dragging:
    print("Mouse Motion at: ", event.position)
    prints({screenStartPosition=screenStartPosition, mouseStartPosition=mouseStartPosition});
    self.position = (mouseStartPosition - event.position) + screenStartPosition

# func _physics_process(delta):
#   if(dragging):
#     prints(self.position, get_viewport().get_mouse_position());
#     self.position = lerp(self.position, get_viewport().get_mouse_position(), 25 * delta)
