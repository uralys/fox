extends Node

signal onPress

@export var onlyOnce: bool = true
@export var sound: bool = true
@export var MIN_MS_BETWEEN_PRESS: int = 700

var nbPressed = 0
var lastPress = Time.get_ticks_msec()

func _gui_input(event):
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
    var now = Time.get_ticks_msec()
    var elapsedTime = now - lastPress

    if(nbPressed > 0 and int(elapsedTime) < MIN_MS_BETWEEN_PRESS):
      return

    lastPress = now
    nbPressed += 1

    if(onlyOnce and nbPressed > 1):
      return

    emit_signal('onPress')

    if(sound):
      Sound.play(Sound.BUTTON_PRESS)
