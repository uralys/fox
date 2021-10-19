extends TextureRect

signal onPress
signal onRelease

func _gui_input(event):
  if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
    emit_signal("onPress")

  if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed:
    emit_signal("onRelease")
