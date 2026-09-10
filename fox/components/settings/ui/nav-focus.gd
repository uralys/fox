extends RefCounted

# ==============================================================================
# nav-focus.gd — the gamepad/keyboard focus highlight of the settings rows (fox).
#
# Scales a Control around its centre to mark the focused row. Layout-neutral: a
# render transform, not a size change, so its neighbours keep their place. The
# pivot is re-centred on every call so it stays correct after a resize.
#
# Ported from faraday-corridors' NavFocus; kept class_name-free (preloaded) so it
# never collides with the game's own.
# ==============================================================================

const FOCUS_SCALE := 1.06

static func apply_scale(control: Control, focused: bool) -> void:
	control.pivot_offset = control.size * 0.5
	var s: float = FOCUS_SCALE if focused else 1.0
	control.scale = Vector2(s, s)
