extends Area2D

# ------------------------------------------------------------------------------

var draggable
var parentReference
var additionalDragData
var params = {}
var mouseStartPosition
var screenStartPosition
var useBoundaries ## usually the draggable itself to use its size

@export var inputPriority: int = 0 # the lower the more priority
@export var minDragTime: int = 20
@export var minPressTime: int = 150
@export var longPressTime: int = 500

@export var dragAfterLongPress: bool = false
@export var useManualDragStart: bool = false
@export var type = 'default'

var _dragging = false
var _pressing = false

var isPressing = false
var isLongPressing = false
var lastPress = Time.get_ticks_msec()

# ------------------------------------------------------------------------------

signal pressed
signal pressing
signal longPress

signal droppedOnDroppable
signal droppedIntheWild
signal foundDroppable
signal leftDroppable

signal startedDragging

# ------------------------------------------------------------------------------

func _ready():
  connect("input_event", onInput)

# ------------------------------------------------------------------------------

func _physics_process(_delta):
  if _pressing:
    if(Gesture.shouldConcedePriority(self)):
      resetInteraction()
      return

    if(Gesture.isDragging() and Gesture.currentDraggable() != draggable):
      resetInteraction()
      return

    var now = Time.get_ticks_msec()
    var elapsedTime = now - lastPress
    var mousePosition = get_global_mouse_position()

    var mouseDiff = mousePosition - mouseStartPosition
    var minMouseDragTresholdReached = (mouseDiff).length() > 3

    if(draggable \
      and not _dragging
      and minMouseDragTresholdReached \
      and not dragAfterLongPress \
      and not useManualDragStart \
      and elapsedTime > minDragTime):
      _startDragging()

    if(not _dragging and not isPressing and elapsedTime > minPressTime):
      var _accepted = Gesture.acceptTouchable(self)
      if(_accepted):
        isPressing = true
        emit_signal('pressing')
      else:
        resetInteraction()

    if(not _dragging and not isLongPressing and elapsedTime > longPressTime):
      var _accepted = Gesture.acceptTouchable(self)
      if(_accepted):
        isLongPressing = true
        emit_signal('longPress')

        if(draggable \
          and minMouseDragTresholdReached \
          and dragAfterLongPress \
          and not useManualDragStart):
          _startDragging()

      else:
        resetInteraction()


    if(_dragging):
      var zoom = parentReference.scale.x if parentReference else 1
      var newPosition = mouseDiff / zoom + screenStartPosition

      if(useBoundaries):
        var draggableWidth = useBoundaries.get_rect().size.x * draggable.scale.x
        var draggableHeight = useBoundaries.get_rect().size.y * draggable.scale.y

        var xMin = G.W - draggableWidth/2
        var xMax = draggableWidth/2
        var yMin = G.H - draggableHeight/2
        var yMax = draggableHeight/2

        newPosition.x = min(max(newPosition.x, xMin), xMax)
        newPosition.y = min(max(newPosition.y, yMin), yMax)

      draggable.position = lerp(draggable.position, newPosition, 25 * _delta)

# ------------------------------------------------------------------------------

func onInput(_viewport, event, _shape_idx):
  # ---------- mouse down ----------
  if event is InputEventMouseButton \
  and event.button_index == MOUSE_BUTTON_LEFT \
  and event.pressed:
    lastPress = Time.get_ticks_msec()
    mouseStartPosition = get_global_mouse_position()
    _pressing = true

    var globalPosition = get_parent().global_position
    var touchDistance = (mouseStartPosition - globalPosition).length()

    var pressEvent = {
      zIndex = get_parent().z_index,
      touchable = self,
      from = get_parent(),
      touchDistance = touchDistance,
      mouseStartPosition = mouseStartPosition
    }

    Gesture.addPressedItem(pressEvent)
    return

# ------------------------------------------------------------------------------

func _startDragging():
  manualStartDragging()
  emit_signal('startedDragging')

# ------------------------------------------------------------------------------

func resetInteraction():
  _dragging = false
  _pressing = false

  isPressing = false
  isLongPressing = false

  Gesture.removePressedItem(self)

# ------------------------------------------------------------------------------

func _unhandled_input(event):
  if _pressing \
    and event is InputEventMouseButton \
    and event.button_index == MOUSE_BUTTON_LEFT \
    and !event.pressed:

    if(_dragging):
      Gesture.handleDraggingEnd()
    else:
      var _accepted = Gesture.acceptTouchable(self)
      if(_accepted):
        emit_signal('pressed')

    resetInteraction()

# ------------------------------------------------------------------------------

func manualStartDragging():
  if(not draggable):
    G.log('[color=pink]You must set your draggable object before to use dragging. Use prepareDraggable()[/color]')
    return

  _pressing = true
  _dragging = true
  mouseStartPosition = get_global_mouse_position()

  Gesture.startDragging(self, draggable, additionalDragData)

  screenStartPosition = draggable.position

# ------------------------------------------------------------------------------

func prepareDraggable(_options):
  draggable = __.Get('draggable', _options)

  if(!draggable):
    G.log('[color=pink]You must pass your draggable within the options: prepareDraggable({draggable=item})[/color]')
    return

  type = __.GetOr('default', 'type', _options)
  parentReference = __.Get('parentReference', _options)
  useBoundaries = __.Get('useBoundaries', _options)
  useManualDragStart = __.GetOr(false, 'useManualDragStart', _options)

# ------------------------------------------------------------------------------

func resetDraggingPosition():
  screenStartPosition = draggable.position

func resetDraggable():
  draggable = null
