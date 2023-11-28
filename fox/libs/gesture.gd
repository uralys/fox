# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

var state = {
  dragArea = null,
  draggable = null,
  droppable = null,
  DRAGGING_DATA = null,
  PRESSED_ITEMS = [],
  ACCEPTED_PRESSED_ITEMS = [],
}

# ------------------------------------------------------------------------------

func addPressedItem(touchable):
  state.PRESSED_ITEMS.append(touchable)

# ------------------------------------------------------------------------------

func removePressedItem(touchable):
  state.PRESSED_ITEMS.erase(touchable)
  state.ACCEPTED_PRESSED_ITEMS.erase(touchable)

# ------------------------------------------------------------------------------

func shouldConcedePriority(touchable):
  if(state.PRESSED_ITEMS.size() > 0):
    for item in state.PRESSED_ITEMS:
      if(item.inputPriority < touchable.inputPriority):
        return true

  return false

# ------------------------------------------------------------------------------

func acceptTouchable(touchable):
  state.ACCEPTED_PRESSED_ITEMS.append(touchable)

# ------------------------------------------------------------------------------

func isDragging():
  return state.DRAGGING_DATA != null

func getDraggingData():
  return state.DRAGGING_DATA

func currentDragArea():
  return __.Get('DRAGGING_DATA.dragArea', state)

func currentDraggable():
  return __.Get('DRAGGING_DATA.draggable', state)

func currentDroppable():
  return __.Get('DRAGGING_DATA.droppable', state)

# ------------------------------------------------------------------------------

func startDragging(dragArea, draggable, additionalDragData):
  state.DRAGGING_DATA = {
    dragArea = dragArea,
    draggable = draggable
  }

  if(additionalDragData):
    for key in additionalDragData.keys():
      var value = additionalDragData[key]
      __.Set(value, key, state.DRAGGING_DATA)

# ------------------------------------------------------------------------------

func verifyDroppableOnEnter(_droppable, acceptedType: String):
  var dragArea = currentDragArea()

  if(not dragArea):
    return

  if(dragArea.type == acceptedType):
    state.DRAGGING_DATA.droppable = _droppable
    dragArea.emit_signal('foundDroppable', _droppable)

    _droppable.emit_signal('dropActived')

# ------------------------------------------------------------------------------

func verifyDroppableOnExit(_droppable, acceptedType: String):
  var dragArea = currentDragArea()
  if(not dragArea):
    return

  if(dragArea.type == acceptedType):
    state.DRAGGING_DATA.droppable = null
    dragArea.emit_signal('leftDroppable', _droppable)
    _droppable.emit_signal('dropDeactived')

# ------------------------------------------------------------------------------

func handleDraggingEnd():
  var dragArea = currentDragArea()
  var draggable = currentDraggable()
  var droppable = currentDroppable()

  if(droppable):
    droppable.emit_signal('received', state.DRAGGING_DATA, draggable.position)
    dragArea.emit_signal('droppedOnDroppable', state.DRAGGING_DATA, draggable.position)
  else:
    dragArea.emit_signal('droppedIntheWild', draggable.position)

  state.DRAGGING_DATA = null

# ------------------------------------------------------------------------------

func switchDraggingTo(newDraggable, parentReference = null):
  var droppable = currentDroppable()
  var dragArea = currentDragArea()
  dragArea.resetInteraction()

  var newDragArea = newDraggable.get_node('interactiveArea2D')

  newDragArea.prepareDraggable({
    draggable = newDraggable,
    type = dragArea.type,
    parentReference = parentReference
  })

  newDragArea.manualStartDragging()

  state.DRAGGING_DATA.droppable = droppable
