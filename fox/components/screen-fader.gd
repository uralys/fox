extends CanvasLayer

export(float) var duration = 1

func _ready():
  var opacityTween = Tween.new()
  add_child(opacityTween)

  $rect.visible = true
  $rect.rect_size = get_viewport().get_visible_rect().size

  opacityTween.interpolate_property(
    $rect,
    'modulate:a',
    1, 0,
    duration,
    Tween.TRANS_LINEAR, Tween.EASE_OUT
  )

  opacityTween.start()
