# Interactive Area2D

An `Area2D` able to listen for mouse / touch events.
The Node where this interactive `Area2D` is attached can be touched and/or dragged.

## Setup

- Attach the [interactiveArea2D](../../fox/behaviours/interactiveArea2D.tscn) Scene as child to your Node.

- Add a `CollisionShape2D` to the `interactiveArea` Node and set its shape e.g(`RectangleShape2D`).

- Set your shape size and position.

**important note**: be sure you have no `Control` in the parent tree, it could intercept the  events. Read the doc about [Godot Input Events](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html#how-does-it-work)

## Code

Declare the `area` in your script to allow connecting listeners:

```gdscript
@onready var interactiveArea2D = $interactiveArea2D
```

Now you can attach listeners to the `touchable` and `draggable` areas:

```gdscript
func _ready():
  interactiveArea2D.connect('dragged', _dragged)
  interactiveArea2D.connect('startedDragging', _startedDragging)
  interactiveArea2D.connect('press', pressed)

# --------------------------------------

func _dragged(_position):
  G.log('dragged', name, _position);

func _startedDragging():
  G.log('started dragging', name);

func pressed():
  G.log('pressed on', name);
```

## Dragging

To drag your Node needs few more settings: you need to tell it what Node is to be dragged, and what parent it's dragged on, to apply the parent scale to the new positions.

```gdscript
interactiveArea2D.draggable = self
interactiveArea2D.parentReference = get_parent()
```

By default the dragging starts immediately but you can ask to start after a `longPress`

```gdscript
interactiveArea2D.afterLongPress = true
```

Also, you may have scaled a parent. If so, you need to tell the `interactiveArea2D` what scale to apply to calculate the dragged position.

```gdscript
var parent = $your/scaled/parent
interactiveArea2D.zoom = parent.scale.x
```
