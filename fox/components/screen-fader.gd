extends CanvasLayer

@export var duration: float = 1

func _ready():
  $rect.visible = true
  $rect.size = get_viewport().get_visible_rect().size

  Animate.to($rect, {
    propertyPath = "modulate:a",
    toValue = 0,
    duration = duration
  })
