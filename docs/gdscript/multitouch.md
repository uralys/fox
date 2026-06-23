# Multitouch Area

`multitouchArea` is an `Area2D` that emits high-level press/drag signals from
both mouse and touch input. Unlike [interactiveArea2D](./interactive-area-2d.md)
(which is built for drag & drop with priority arbitration), `multitouchArea` is a
lightweight listener for "something was pressed/dragged here" — handy for a
canvas, a fullscreen input catcher, or drawing.

## Setup

Attach the [multitouchArea](../../fox/behaviours/multitouchArea.tscn) scene to a
Node and give it a `CollisionShape2D`.

To make it cover the whole screen, enable `fullscreen`: the collision shape is
resized to `G.W × G.H` and kept in sync on window resize.

```gdscript
@onready var area = $multitouchArea  # with fullscreen = true
```

## Signals

Each signal carries a normalised `event = {position, pressed, index}` (`index`
disambiguates fingers / buttons for multitouch):

| signal | when |
|--------|------|
| `pressing(event)` | press started (mouse down / touch down) |
| `dragging(event)` | pointer moved while pressed |
| `pressed(event)` | released |
| `stopPressing(event)` | released (companion to `pressed`) |
| `longPress(latestPressEvent)` | held longer than `longPressTime` |

## Exports

- `fullscreen: bool` — auto-fit the collision shape to the screen
- `longPressTime: int = 500` — milliseconds before `longPress` fires

## Example

```gdscript
func _ready():
  area.pressing.connect(_onPress)
  area.dragging.connect(_onDrag)
  area.longPress.connect(_onLongPress)

func _onPress(event):
  G.log('pressed at', event.position)

func _onDrag(event):
  draw_to(event.position)
```

## Related behaviours

- `behaviours/rotation.gd` — attach to a `TextureRect` to spin it continuously;
  exposes a single `speed` export (radians/second factor).
