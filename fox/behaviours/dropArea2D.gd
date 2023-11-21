extends Area2D

# ------------------------------------------------------------------------------

@export var acceptedType = 'default'

# ------------------------------------------------------------------------------

signal dropActived
signal dropDeactived
signal received # triggered from interactiveArea

# ------------------------------------------------------------------------------

func _ready():
  connect("mouse_entered", mouse_entered)
  connect("mouse_exited", mouse_exited)

# ------------------------------------------------------------------------------

func mouse_entered():
  var draggerType = __.Get('DRAGGING_DATA.dragger.type' , G.state)

  if(draggerType == acceptedType):
    G.state.DRAGGING_DATA.droppable = self
    G.state.DRAGGING_DATA.dragger.emit_signal('foundDroppable', self)
    emit_signal("dropActived")

# ------------------------------------------------------------------------------

func mouse_exited():
  var draggerType = __.Get('DRAGGING_DATA.dragger.type' , G.state)
  if(draggerType == acceptedType):
    G.state.DRAGGING_DATA.droppable = null
    G.state.DRAGGING_DATA.dragger.emit_signal('leftDroppable', self)
    emit_signal("dropDeactived")
