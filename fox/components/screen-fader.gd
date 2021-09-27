extends ColorRect

func _ready():
  var opacityTween = Tween.new()
  add_child(opacityTween)

  visible = true

  opacityTween.interpolate_property(
    self,
    'modulate:a',
    1, 0,
    0.5,
    Tween.TRANS_LINEAR, Tween.EASE_OUT
  )

  opacityTween.start()
