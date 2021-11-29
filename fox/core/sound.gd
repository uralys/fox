# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

var SOUNDS

# ------------------------------------------------------------------------------

var BUTTON_PRESS = "onButtonPress"

# ------------------------------------------------------------------------------

func _ready():
  SOUNDS = Node.new()
  $'/root/app'.add_child(SOUNDS)

# ------------------------------------------------------------------------------

func play(path):
  var sound = AudioStreamPlayer.new()
  sound.pause_mode = PAUSE_MODE_PROCESS

  var stream = load(path)
  sound.stream = stream
  SOUNDS.add_child(sound)

  sound.play()

  return sound

# ------------------------------------------------------------------------------
