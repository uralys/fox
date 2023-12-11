# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

var state = {
  dragArea = null,
  draggable = null,
  droppable = null,
  DRAGGING_DATA = null,
  PRESS_EVENTS = []
}

# ------------------------------------------------------------------------------

func findPressEvent(touchable):
  var pressEvents = state.PRESS_EVENTS.filter(func(_event):
    return _event.touchable == touchable
  )

  if(pressEvents.size() > 0):
    return pressEvents[0]

# ------------------------------------------------------------------------------

func addPressedItem(pressEvent):
  state.PRESS_EVENTS.append(pressEvent)
  state.PRESS_EVENTS.sort_custom(func(evA, evB):
    if(evA.zIndex > evA.zIndex): return true
    return evA.touchDistance < evB.touchDistance
  )

# ------------------------------------------------------------------------------

func removePressedItem(touchable):
  # another touchable has already claimed acceptation
  if(state.PRESS_EVENTS.size() == 0):
    return

  var pressEvent = findPressEvent(touchable)

  if(pressEvent):
    state.PRESS_EVENTS.erase(pressEvent)

# ------------------------------------------------------------------------------

func shouldConcedePriority(touchable):
  if(state.PRESS_EVENTS.size() > 0):
    for pressEvent in state.PRESS_EVENTS:
      var priority = __.GetOr(10000, 'touchable.inputPriority', pressEvent)
      if(priority < touchable.inputPriority):
        return true

  return false

# ------------------------------------------------------------------------------

func acceptTouchable(touchable):
  # another touchable has already been accepted
  if(state.PRESS_EVENTS.size() == 0):
    return false

  # PRESS_EVENTS are sorted as soon as they are added during addPressedItem
  var isAccepted = state.PRESS_EVENTS[0].touchable == touchable

  if(isAccepted):
    state.PRESS_EVENTS = [state.PRESS_EVENTS[0]]
    return true

  return false

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
