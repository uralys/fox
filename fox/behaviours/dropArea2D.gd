extends Area2D

# ------------------------------------------------------------------------------

@export var acceptedType = 'default'

# ------------------------------------------------------------------------------

signal dropActived
signal dropDeactived
signal received # triggered from interactiveArea

# ------------------------------------------------------------------------------

func _ready():
  connect("mouse_entered", mouse_entered)
  connect("mouse_exited", mouse_exited)

# ------------------------------------------------------------------------------

func mouse_entered():
  Gesture.verifyDroppableOnEnter(self, acceptedType)

# ------------------------------------------------------------------------------

func mouse_exited():
  Gesture.verifyDroppableOnExit(self, acceptedType)
