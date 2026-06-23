# Animations

`Animate` wraps Godot `Tween`s behind a small option-based API you can call from
anywhere. It handles delays, easing, "from/to" values, arrays of objects, and an
`onFinished` callback for you.

See also [`Motion`](./motion.md) for continuous, sampleable idle motion (the
`Tween` vs `Motion` split: `Animate` for punctual `A → B` moves, `Motion` for
forever-looping juice), and [`Framer`](#framer) for sprite-frame animation.

## Options

Most functions take `(object, options)` where `options` is a dictionary:

| key | default | description |
|-----|---------|-------------|
| `propertyPath` | — | property to animate, dotted (e.g. `position`, `modulate:a`, `scale`) |
| `toValue` | current | target value |
| `fromValue` | current | start value (set before animating) |
| `duration` | `0.75` | seconds |
| `delay` | `0` | seconds before starting |
| `transition` | engine default | `Tween.TRANS_*` |
| `easing` | engine default | `Tween.EASE_*` |
| `onFinished` | — | callback when the tween ends |
| `delayBetweenElements` | `0` | when animating an array, stagger between items |
| `signalToWait` | `animationDone` | user signal emitted on completion |

## Core API

- `Animate.to(objectOrArray, options)` — animate toward `toValue`. Accepts an
  array to animate many nodes (optionally staggered).
- `Animate.from(object, options)` — set `fromValue` then animate back to the
  current value.
- `Animate.toAndBack(object, options)` — animate to `toValue` then back.

```gdscript
Animate.to(yourObject, {
  propertyPath = 'position',
  toValue = Vector2(200, 200),
  duration = 0.5,
  easing = Tween.EASE_IN_OUT,
  delay = 0.3
})
```

Animating several nodes with a delay between each, then logging:

```gdscript
Animate.to([potion, car, book], {
  propertyPath = "position",
  toValue = Vector2(0, 0),
  delayBetweenElements = 1,
  onFinished = func(): G.log('DONE')
})
```

## Show / hide

Fade helpers driving `modulate:a` and `visible`:

- `Animate.show(object, duration = 0.3, delay = 0.0, doNotHide = false)`
- `Animate.hide(object, duration = 0.3, delay = 0)` — sets `visible = false` when
  done

```gdscript
Animate.show(car)
await Wait.forSomeTime(car, 2).timeout
Animate.to(car, {propertyPath = 'position', toValue = Vector2(200, 200)})
```

## Effects

- `Animate.flash(object, options)` — quick brightness flash (`modulate:v`),
  `duration` default `0.2`.
- `Animate.bounce(object, options)` — scale pop; `upScale` (default `0.05`) and
  `duration` (default `0.25`). Safe to spam: it tracks the base scale so repeated
  calls do not grow the node.
- `Animate.swing(object, options)` — loops back-and-forth between `fromValue` and
  `toValue` (or `fromValue * ratio`) until the object is freed.
- `Animate.zoomIn(objectOrArray, options)` — scale up from `fromScaleRatio`
  (default `0.9`) to the current scale.
- `Animate.collect(object, options)` — "collectible" effect: spread items on a
  circle then gather them toward `toPosition` while fading/shrinking; frees the
  object at the end. Options include `fromPosition`, `toPosition`, `myNum`,
  `nbCollectables`, `gatherDurationSec`, `spreadRadius`, `onFinished`.

```gdscript
Animate.bounce(button)
Animate.flash(coin, {duration = 0.15})
```

> `Animate.appear()` and `Animate.disappear()` exist but are tuned for a specific
> game (Lockey Land) — prefer `show`/`hide`/`zoomIn` for general use.

## Framer

`framer.gd` (`fox/animations/framer.gd`) tweens a sprite's `frame` property to
play a spritesheet animation. Attach it as a child of an `AnimatedSprite`-style
node (it animates its parent's `frame`):

```gdscript
@onready var framer = $framer

func walk():
  framer.animateFrames(0, 8)   # play frames 0 → 8
```

`animateFrames(fromFrame, toFrame, reverse = false, maxNbFrames = 0, totalDuration = 0.3, duration = null)`
also supports looping spritesheets: pass `maxNbFrames` so it wraps around the end
of the sheet (e.g. `30 → 2` plays `30 → 31 → 0 → 1 → 2`).
