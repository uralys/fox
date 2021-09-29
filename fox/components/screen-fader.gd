extends CanvasLayer

func _ready():
  var opacityTween = Tween.new()
  add_child(opacityTween)

  $rect.visible = true
  $rect.rect_size = get_viewport().get_visible_rect().size

  opacityTween.interpolate_property(
    $rect,
    'modulate:a',
    1, 0,
    0.5,
    Tween.TRANS_LINEAR, Tween.EASE_OUT
  )

  opacityTween.start()
