extends Area2D

# ------------------------------------------------------------------------------

signal dropActived
signal dropDeactived
signal received

# ------------------------------------------------------------------------------

func _ready():
  connect("mouse_entered", mouse_entered)
  connect("mouse_exited", mouse_exited)

# ------------------------------------------------------------------------------

func mouse_entered():
  if(G.state.DRAGGING_DATA):
    G.state.DRAGGING_DATA.droppable = self
    emit_signal("dropActived")

# ------------------------------------------------------------------------------

func mouse_exited():
  if(G.state.DRAGGING_DATA):
    G.state.DRAGGING_DATA.droppable = null
    emit_signal("dropDeactived")

# ------------------------------------------------------------------------------

func onDrop(draggedData):
  emit_signal("received", draggedData)

