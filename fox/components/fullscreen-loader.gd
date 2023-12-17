# ------------------------------------------------------------------------------

extends CanvasLayer

# ------------------------------------------------------------------------------

@onready var panel = $panel
@onready var circle = $panel/circle

@export var lod = 3.0

# ------------------------------------------------------------------------------

var removing = false
var showing = false

# ------------------------------------------------------------------------------

func _ready():
  panel.material = panel.material.duplicate()
  panel.material.set_shader_parameter('lod', 0.0)
  removing = false
  showing = true
  Animate.show(circle)

# ------------------------------------------------------------------------------

func remove():
  Animate.hide(circle)
  removing = true
  showing = false

# ------------------------------------------------------------------------------

func _physics_process(delta):
  var current = panel.material.get_shader_parameter('lod')

  if(showing):
    var newValue = min(lod, current + delta * 7)
    panel.material.set_shader_parameter('lod', newValue)

  elif(removing):
    var newValue = current - delta * 7
    panel.material.set_shader_parameter('lod', newValue)

    if(current <= 0):
      get_parent().remove_child(self)
