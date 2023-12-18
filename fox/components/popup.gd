extends ReferenceRect

# ------------------------------------------------------------------------------

@onready var blur = $blur
@onready var content = $content

@onready var closeButton = $content/closeButton

var closing = false
var showing = false

var thisPopupPauseEngine = false

# ------------------------------------------------------------------------------

func _ready():
  if(thisPopupPauseEngine):
    get_tree().paused = true

  showing = true
  blur.material.set_shader_parameter('blur_amount', 0)

  closeButton.connect('pressed', close)
  Animate.show(content)

func _physics_process(delta):
  var current = blur.material.get_shader_parameter('blur_amount')
  if(closing):
    var newValue = current - delta * 200

    blur.material.set_shader_parameter('blur_amount', newValue)

    if(newValue < 0):
      get_parent().remove_child(self)
      queue_free()

  elif(showing):
    var newValue = current + delta * 200

    if(newValue < 60):
      blur.material.set_shader_parameter('blur_amount', newValue)
    else:
      showing = false

# ------------------------------------------------------------------------------

func close():
  closing = true

  Sound.play(Sound.PRESS)

  if(thisPopupPauseEngine):
    get_tree().paused = false

  Animate.to(content, {
    propertyPath = 'modulate:a',
    toValue = 0,
    duration = 0.3
  })

# ------------------------------------------------------------------------------
