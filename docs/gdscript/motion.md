# Motion

`Motion` provides generic, **sampleable** motion functions for procedural
"juice": continuous idle motion (floating, wobble, breathing) that you read
every frame and add to a node.

Use it where a `Tween` does not fit: a Tween animates a punctual `A → B` move,
while `Motion` gives you a value to sample forever in `_process`.

It is inspired by the motion functions of 2D BOY's *Boy* framework (the engine
behind *World of Goo*): `SmoothTransitionFunction` and `SinFunction2D`.

## Usage

Sample a function each frame with an accumulating time `t` and add it to a base
value:

```gdscript
var basePosition: Vector2
var t := 0.0

func _ready():
  basePosition = position

func _process(delta):
  t += delta
  position = basePosition + Motion.bob(t, 8.0, 0.5)
  scale    = Vector2.ONE * Motion.breathe(t, 0.05, 0.8)
  rotation = deg_to_rad(Motion.wobbleDeg(t, 4.0, 1.2))
```

`frequency` is in Hz (cycles per second), `phase` in radians. Offsetting the
phase per node desynchronizes a crowd of objects so they do not pulse in unison.

## API

### Oscillators

- `Motion.oscillate(t, amplitude, frequency, phase = 0.0) -> float`
  1D sine oscillation around 0, within `[-amplitude, amplitude]`.
- `Motion.oscillate2D(t, amplitude: Vector2, frequency: Vector2, phase = Vector2.ZERO) -> Vector2`
  Independent oscillation per axis (Boy's `SinFunction2D`). Combine axes for
  circular / figure-eight motion.

### Ready-made offsets

- `Motion.bob(t, amplitude, frequency, phase = 0.0) -> Vector2`
  Vertical floating offset (idle bob).
- `Motion.sway(t, amplitude, frequency, phase = 0.0) -> Vector2`
  Horizontal swaying offset.
- `Motion.breathe(t, amplitude, frequency, base = 1.0, phase = 0.0) -> float`
  Pulsing scalar around `base` (breathing scale): `base ± amplitude`.
- `Motion.wobbleDeg(t, amplitudeDeg, frequency, phase = 0.0) -> float`
  Rotation wobble in **degrees**, within `[-amplitudeDeg, amplitudeDeg]`.

### Smooth transition

- `Motion.smooth(x, x0, x1, y0, y1) -> float`
  Smooth cosine transition from `y0` to `y1` as `x` goes from `x0` to `x1`
  (Boy's `SmoothTransitionFunction`). `x` is clamped to `[x0, x1]`, so it is a
  handy ease for mapping any input range to an eased output:

  ```gdscript
  # fade an alpha as a value crosses [0, 100]
  modulate.a = Motion.smooth(distance, 0.0, 100.0, 1.0, 0.0)
  ```
