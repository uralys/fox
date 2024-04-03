extends ReferenceRect

# ------------------------------------------------------------------------------

@onready var blur = $blur
@onready var panel = $panel

@onready var closeButton = $panel/closeButton

# ------------------------------------------------------------------------------

var closing = false
var showing = false

var thisPopupPauseEngine = false

# ------------------------------------------------------------------------------

func _ready():
  if(thisPopupPauseEngine):
    get_tree().paused = true

  showing = true
  blur.material.set_shader_parameter('blur_amount', 0)

  if(closeButton):
    if(closeButton.has_node('interactiveArea2D')):
      closeButton.get_node('interactiveArea2D').connect('pressed', close)
    else:
      closeButton.connect('pressed', close)

  Animate.show(panel)

# ------------------------------------------------------------------------------

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

  if(__.Get('PRESS', Sound)):
    Sound.play(Sound.PRESS)

  if(thisPopupPauseEngine):
    get_tree().paused = false

  Animate.to(panel, {
    propertyPath = 'modulate:a',
    toValue = 0,
    duration = 0.3
  })

# ------------------------------------------------------------------------------
