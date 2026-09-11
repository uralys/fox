extends TextureRect

@export var speed = 10

func _process(delta):
  rotation += delta * speed
