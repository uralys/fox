class_name OctagonGeom
extends RefCounted

# ==============================================================================
# OctagonGeom — shared geometry helpers for chamfered/cut rectangular polygons.
# Single source of truth for octagon and hexagonal-pillbox shapes used by
# BeveledCard and NeonBadge.
# ==============================================================================

# 8-vertex octagon: rectangle with all four corners cut at 45° by `cut`.
# Vertices ordered clockwise starting at the top-left chamfer.
static func points(rect: Rect2, cut: float) -> PackedVector2Array:
	var x = rect.position.x
	var y = rect.position.y
	var w = rect.size.x
	var h = rect.size.y
	return PackedVector2Array([
		Vector2(x + cut, y),
		Vector2(x + w - cut, y),
		Vector2(x + w, y + cut),
		Vector2(x + w, y + h - cut),
		Vector2(x + w - cut, y + h),
		Vector2(x + cut, y + h),
		Vector2(x, y + h - cut),
		Vector2(x, y + cut)
	])

# 6-vertex hexagonal pillbox: rectangle with pointed left & right ends meeting
# at a single vertex on the vertical midpoint. Top and bottom edges are inset
# by `cut`. Used for HUD-style status bars.
static func hex_pillbox(rect: Rect2, cut: float) -> PackedVector2Array:
	var x = rect.position.x
	var y = rect.position.y
	var w = rect.size.x
	var h = rect.size.y
	return PackedVector2Array([
		Vector2(x + cut, y),
		Vector2(x + w - cut, y),
		Vector2(x + w, y + h * 0.5),
		Vector2(x + w - cut, y + h),
		Vector2(x + cut, y + h),
		Vector2(x, y + h * 0.5)
	])
