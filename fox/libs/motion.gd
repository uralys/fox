# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

class_name FoxMotion

# ------------------------------------------------------------------------------
#
# Generic, sampleable motion functions for procedural "juice":
# continuous idle motion (floating, wobble, breathing) that you read every
# frame and add to a node, where a Tween only covers ponctual A -> B moves.
#
# Inspired by the motion functions of 2D BOY's "Boy" framework (the engine
# behind World of Goo): SmoothTransitionFunction and SinFunction2D.
# Reference: https://github.com/MlgmXyysd/2D-BOY-s-Boy-Framework
#
# Usage (in _process):
#   position = basePosition + FoxMotion.bob(t, 8.0, 0.5)
#   scale    = Vector2.ONE * FoxMotion.breathe(t, 0.05, 0.8)
#   rotation = deg_to_rad(FoxMotion.wobbleDeg(t, 4.0, 1.2))
#
# `frequency` is in Hz (cycles per second), `phase` in radians.
#
# ------------------------------------------------------------------------------

# smooth cosine transition from y0 to y1 as x goes from x0 to x1
# (Boy's SmoothTransitionFunction). x is clamped to [x0, x1].
static func smooth(x: float, x0: float, x1: float, y0: float, y1: float) -> float:
  if x0 == x1:
    return y1

  var t = clampf((x - x0) / (x1 - x0), 0.0, 1.0)
  return y0 + ((1.0 - cos(t * PI)) / 2.0) * (y1 - y0)

# ------------------------------------------------------------------------------

# 1D sine oscillation around 0: ranges within [-amplitude, amplitude]
static func oscillate(t: float, amplitude: float, frequency: float, phase: float = 0.0) -> float:
  return amplitude * sin(TAU * frequency * t + phase)

# ------------------------------------------------------------------------------

# 2D sine oscillation (Boy's SinFunction2D): independent amplitude, frequency
# and phase per axis. Combine two axes to get circular / figure-eight motion.
static func oscillate2D(
  t: float,
  amplitude: Vector2,
  frequency: Vector2,
  phase: Vector2 = Vector2.ZERO
) -> Vector2:
  return Vector2(
    oscillate(t, amplitude.x, frequency.x, phase.x),
    oscillate(t, amplitude.y, frequency.y, phase.y)
  )

# ------------------------------------------------------------------------------

# vertical floating offset (World of Goo idle bob)
static func bob(t: float, amplitude: float, frequency: float, phase: float = 0.0) -> Vector2:
  return Vector2(0.0, oscillate(t, amplitude, frequency, phase))

# ------------------------------------------------------------------------------

# horizontal swaying offset
static func sway(t: float, amplitude: float, frequency: float, phase: float = 0.0) -> Vector2:
  return Vector2(oscillate(t, amplitude, frequency, phase), 0.0)

# ------------------------------------------------------------------------------

# pulsing scalar around `base` (breathing scale): base +/- amplitude
static func breathe(t: float, amplitude: float, frequency: float, base: float = 1.0, phase: float = 0.0) -> float:
  return base + oscillate(t, amplitude, frequency, phase)

# ------------------------------------------------------------------------------

# rotation wobble in degrees, oscillating within [-amplitudeDeg, amplitudeDeg]
static func wobbleDeg(t: float, amplitudeDeg: float, frequency: float, phase: float = 0.0) -> float:
  return oscillate(t, amplitudeDeg, frequency, phase)
