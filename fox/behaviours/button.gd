extends Node

signal press
signal pressing
signal longPress

@export var onlyOnce: bool = true
@export var sound: bool = true
@export var MIN_MS_BETWEEN_PRESS: int = 700

var _pressing = false
var isPressing = false
var nbPressed = 0
var lastPress = Time.get_ticks_msec()

# ------------------------------------------------------------------------------

func _physics_process(_delta):
  if _pressing:
    var now = Time.get_ticks_msec()
    var elapsedTime = now - lastPress

    if(not isPressing and elapsedTime > 150):
      emit_signal('pressing')
      isPressing = true

    if(elapsedTime > 750):
      emit_signal('longPress')

# ------------------------------------------------------------------------------

func _gui_input(event):
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
    _pressing = true

    var now = Time.get_ticks_msec()
    var elapsedTime = now - lastPress

    if(nbPressed > 0 and int(elapsedTime) < MIN_MS_BETWEEN_PRESS):
      return

    lastPress = now
    nbPressed += 1

    if(onlyOnce and nbPressed > 1):
      return

    # if(sound):
    #   Sound.play(Sound.BUTTON_PRESS)

  if _pressing \
  and event is InputEventMouseButton \
  and event.button_index == MOUSE_BUTTON_LEFT \
  and not event.pressed:
    # mouse up
    _pressing = false
    isPressing = false

    emit_signal('press')
