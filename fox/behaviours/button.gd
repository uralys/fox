extends TextureRect

signal onPress
signal onRelease

export(bool) var onlyOnce = true

var nbPressed = 0

func _gui_input(event):
  if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
    nbPressed += 1

    if(onlyOnce and nbPressed > 1):
      return

    emit_signal("onPress")

  if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed:
    emit_signal("onRelease")
