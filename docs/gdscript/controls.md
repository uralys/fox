# Controls

`Controls` is a generic input layer. It normalises keyboard, D-pad, analog
stick, face buttons and triggers into **raw, device-agnostic signals**, so your
game listens to one vocabulary regardless of the controller (keyboard, Steam
Deck, PlayStation, Xbox, Switch…).

It carries **zero game semantics**: it only says "a direction went down", "the
stick latched LEFT", "the confirm button was pressed". Your own interpreter
subscribes to these signals and derives gameplay meaning. `Controls` never
references project classes, so every Fox game shares it and keeps its own mapping
on top.

## Setup

Add it as an `Autoload` named `Controls`:

```ini
[autoload]

Controls="*res://fox/libs/controls.gd"
```

## Signals

These are the only public surface.

### Directions

```gdscript
signal direction_pressed(direction: int, from_gamepad: bool)
signal direction_released(direction: int, from_gamepad: bool)
```

Digital directions from arrows / WASD / D-pad. `from_gamepad` tells the source
without re-reading the device (keyboard = `false`, D-pad = `true`).

Directions use a flat 4-way convention:

```gdscript
const DIR_TOP = 0
const DIR_RIGHT = 1
const DIR_BOTTOM = 2
const DIR_LEFT = 3
```

### Analog stick

```gdscript
signal stick_direction_changed(direction: int, magnitude: float)
signal stick_moved(vector: Vector2)
```

- `stick_direction_changed` — the latched dominant 4-way direction after
  hysteresis (`-1` when neutral/released). This is the analog equivalent of the
  digital `direction_pressed`.
- `stick_moved` — the raw dominant-stick vector each frame it moves (for
  telemetry / gauges).

### Buttons

```gdscript
signal button_pressed(action: String)
signal button_released(action: String)
```

`action` is named by physical gamepad **position** (Godot's `JOY_BUTTON_*`
layout), never by game meaning, so the vocabulary survives across controllers:

`button_a`, `button_b`, `button_x`, `button_y`, `start`, `shoulder_left`,
`shoulder_right`, `trigger_left`, `trigger_right`, `stick_left`, `stick_right`.

Keyboard keys fold onto the nearest device action:

| key | action |
|-----|--------|
| `SPACE` / `ENTER` | `button_a` (accept) |
| `ESCAPE` | `button_b` (back) |
| `PAGEUP` | `shoulder_left` |
| `SHIFT` / `PAGEDOWN` | `shoulder_right` |
| `R` | `trigger_left` |

Analog triggers (L2 / R2) are edge-detected with hysteresis, so each pull fires
`button_pressed('trigger_left'/'trigger_right')` once.

### Number row

```gdscript
signal number_pressed(number: int)
```

Keyboard `1`..`9`, kept separate from buttons for indexed actions.

## Example interpreter

```gdscript
func _ready():
  Controls.direction_pressed.connect(_on_direction)
  Controls.stick_direction_changed.connect(_on_stick)
  Controls.button_pressed.connect(_on_button)

func _on_direction(direction: int, from_gamepad: bool):
  move(direction)

func _on_stick(direction: int, _magnitude: float):
  if direction != -1:
    move(direction)

func _on_button(action: String):
  match action:
    'button_a': confirm()
    'button_b': cancel()
```

## Stick tuning

The stick is digital code reading an analog device, so it needs tuning. The
defaults are neutral and **community-aligned** (Godot deadzone / XInput
anti-drift); they only affect the analog stick (keyboard / D-pad are digital and
never reach this path).

The right value is **game-specific** (a fast arcade rusher and a slow puzzle game
want different turn tolerances), so the knobs are public `var`s, not constants:
Fox ships sane defaults and each game pushes its own at boot, without forking Fox.

```gdscript
# e.g. in your own InputTuning.apply() called at startup
Controls.STICK_ENGAGE = 0.6
Controls.STICK_TURN = 0.3
Controls.stick_speed_factor = 0.0
```

| knob | default | role |
|------|---------|------|
| `STICK_ENGAGE` | `0.5` | push past this to latch a direction from neutral |
| `STICK_RELEASE` | `0.25` | fall back below this to re-arm (anti-drift band) |
| `STICK_TURN` | `0.35` | once engaged, re-aim the cardinal at this lower deflection (keyboard-parity, removes turn latency) |
| `STICK_NEUTRAL_DEBOUNCE_MS` | `40` | hold a release briefly so a flick *through* centre reads as a direct turn, not release+press |
| `STICK_TURN_ANGLE_SLOW` | `45.0` | turn cone (degrees) at rest — the classic 45° quadrant split |
| `STICK_TURN_ANGLE_FAST` | `28.0` | turn cone at top speed — a partial diagonal flick still turns |
| `BASE_COMMIT_MS` | `220` | how long a direction must hold to become the new base axis (so brief chicane taps pivot around the main axis) |
| `stick_speed_factor` | `0.0` | set by the game (0..1): how fast the character moves; interpolates the turn cone between SLOW and FAST |

## A note on `keyboard.gd`

`fox/libs/keyboard.gd` is a much simpler, older input helper that emits plain
`direction_up/down/left/right`, `confirm`, `cancel` signals from keyboard and
D-pad only (no analog stick, no tuning). Prefer `Controls` for new games; keep
`Keyboard` only for minimal menus that never touch the analog stick.
