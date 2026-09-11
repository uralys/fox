extends CanvasLayer

signal fade_completed

@export var duration: float = 1
@export var fade_in: bool = false

func _ready():
  $rect.visible = true
  $rect.size = get_viewport().get_visible_rect().size

  if fade_in:
    $rect.modulate.a = 0
    Animate.to($rect, {
      propertyPath = "modulate:a",
      toValue = 1,
      duration = duration,
      onFinished = func(): fade_completed.emit()
    })
  else:
    Animate.to($rect, {
      propertyPath = "modulate:a",
      toValue = 0,
      duration = duration,
      onFinished = func(): fade_completed.emit()
    })
