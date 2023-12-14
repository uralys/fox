# ------------------------------------------------------------------------------

extends CanvasLayer

# ------------------------------------------------------------------------------

@onready var panel = $panel
@onready var circle = $panel/circle
@onready var initialLOD = panel.material.get_shader_parameter('lod')

# ------------------------------------------------------------------------------

var removing = false

# ------------------------------------------------------------------------------

func _ready():
  panel.material = panel.material.duplicate()
  removing = false
  Animate.show(circle)

# ------------------------------------------------------------------------------

func remove():
  Animate.hide(circle)
  removing = true

# ------------------------------------------------------------------------------

func _physics_process(delta):
  if(removing):
    var current = panel.material.get_shader_parameter('lod')
    var newValue = current - delta * 7
    panel.material.set_shader_parameter('lod', newValue)

    if(current <= 0):
      get_parent().remove_child(self)
