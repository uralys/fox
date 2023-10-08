extends CanvasLayer

@export var duration: float = 1

func _ready():
  var opacityTween = get_tree().create_tween()
  # add_child(opacityTween)

  $rect.visible = true
  $rect.size = get_viewport().get_visible_rect().size

  opacityTween.tween_property( $rect, "modulate:a", 0, duration)

  # opacityTween.interpolate_value(
  #   $rect.modulate.a,
  #   0,
  #   1, 0,
  #   duration,
  #   Tween.TRANS_LINEAR, Tween.EASE_OUT
  # )

  # opacityTween.start()
