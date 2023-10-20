# Touchable and Draggable

## Setup

Attach the [touchable-and-draggable](../../fox/behaviours/touchableAndDraggable.tscn) Scene as child to your Node.

Declare the `touchable` and `draggable` areas in your script to allow connecting listeners:

```gdscript
@onready var touchListeningArea = $touchListeningArea
@onready var dragListeningArea = $touchListeningArea/dragListeningArea
```

Now you can attach listeners to the `touchable` and `draggable` areas:

```gdscript
func _ready():
  dragListeningArea.connect('dragged', _dragged)
  dragListeningArea.connect('startedDragging', _startedDragging)
  touchListeningArea.connect('press', pressed)

# --------------------------------------

func _dragged(_position):
  G.log('dragged', name, _position);

func _startedDragging():
  G.log('started dragging', name);

func pressed():
  G.log('pressed on', name);

```

## Dragging

The `dragListeningArea` needs one more setting: you need to tell it what Node is to be dragged.

```gdscript
dragListeningArea.draggable = self
```

By default the dragging starts immediately but you can ask to start after a `longPress`

```gdscript
dragListeningArea.afterLongPress = true
```
