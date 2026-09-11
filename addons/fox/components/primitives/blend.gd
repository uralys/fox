class_name Blend
extends RefCounted

# ------------------------------------------------------------------------------
# Compositing two stacked fills into one, so the pixel is painted once.
#
# The same shape painted twice, one colour over the other, is the most common way
# this codebase spends a draw call for nothing: a floor tint under a white sheen,
# a gate indicator's glow under its core, a badge's deep background under its
# tint. Every one of those pairs composites EXACTLY into a single colour, and a
# `draw_colored_polygon` opens a new batch each time (docs/web-perf.md), so the
# second pass is pure cost.
#
# `over` is the standard source-over blend, un-premultiplied so the result can be
# handed straight to a draw call.
#
# ⛔ Only valid when the two fills cover the SAME geometry and neither is drawn
# with a special blend mode. Two shapes that merely overlap cannot be merged.
# ------------------------------------------------------------------------------

static func over(bottom: Color, top: Color) -> Color:
	var alpha := top.a + bottom.a * (1.0 - top.a)
	if alpha <= 0.0:
		return Color(0.0, 0.0, 0.0, 0.0)
	var weight := bottom.a * (1.0 - top.a)
	return Color(
		(top.r * top.a + bottom.r * weight) / alpha,
		(top.g * top.a + bottom.g * weight) / alpha,
		(top.b * top.a + bottom.b * weight) / alpha,
		alpha
	)
