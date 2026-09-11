class_name JuicyPress
extends RefCounted

# ==============================================================================
# JuicyPress — shared press/release squish animation.
# Single source of truth for the tactile button feel used across fox games.
# - press():   snaps to a squished scale anchored at bottom-center.
# - release(): springs back to Vector2.ONE with EASE_OUT TRANS_QUINT.
# ==============================================================================

const DEFAULT_PRESS_SCALE := Vector2(0.9, 0.7)
const DEFAULT_RESTORE_DURATION := 0.25

static func setup_pivot(control: Control) -> void:
	control.pivot_offset = control.size * Vector2(0.5, 1.0)

static func press(node: CanvasItem, tween: Tween, press_scale: Vector2 = DEFAULT_PRESS_SCALE) -> void:
	if tween: tween.kill()
	if node is Control:
		setup_pivot(node)
	node.scale = press_scale

static func release(node: CanvasItem, restore_duration: float = DEFAULT_RESTORE_DURATION) -> Tween:
	var tween := node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUINT)
	tween.tween_property(node, 'scale', Vector2.ONE, restore_duration)
	return tween
