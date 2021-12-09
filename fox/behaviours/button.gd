extends Node

signal onPress
signal onRelease

export(bool) var onlyOnce = true
export(int) var MIN_MS_BETWEEN_PRESS = 700

var nbPressed = 0
var lastPress = OS.get_ticks_msec()

func _gui_input(event):
  if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
    var now = OS.get_ticks_msec()
    var elapsedTime = now - lastPress

    if(nbPressed > 0 and int(elapsedTime) < MIN_MS_BETWEEN_PRESS):
      return

    lastPress = now
    nbPressed += 1

    if(onlyOnce and nbPressed > 1):
      return

    emit_signal('onPress')
    Sound.play(Sound.BUTTON_PRESS)

  if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed:
    emit_signal('onRelease')
