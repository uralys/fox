# ------------------------------------------------------------------------------

class_name HoloDrawUtils

# ------------------------------------------------------------------------------
#
# Holographic 2D draw helpers shared by HUD/settings primitives.
#
# - draw_spaced / get_spaced_width: manual letter-spacing (Label has no
#   letter-spacing property). Spacing is inserted only between glyphs, never
#   after the last one, so a spaced run keeps the same visual width as its
#   measured get_spaced_width.
# - draw_panel: framed glass panel (fill + outer glow border + bright inner
#   border), colors read from the consuming game's DesignTokens by class_name.
#
# ------------------------------------------------------------------------------

static func draw_spaced(canvas: CanvasItem, font: Font, pos: Vector2, text: String, font_size: int, color: Color, spacing: float):
	var x = pos.x
	for i in range(text.length()):
		var ch = text[i]
		canvas.draw_string(font, Vector2(x, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if i < text.length() - 1:
			x += spacing

# ------------------------------------------------------------------------------

static func get_spaced_width(font: Font, text: String, font_size: int, spacing: float) -> float:
	var w = 0.0
	for i in range(text.length()):
		w += font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if i < text.length() - 1:
			w += spacing
	return w

# ------------------------------------------------------------------------------

static func draw_panel(canvas: CanvasItem, rect: Rect2, color: Color, bright_width: float = 1.5):
	canvas.draw_rect(rect, DesignTokens.Backgrounds.PANEL)
	canvas.draw_rect(rect, Color(color, DesignTokens.Glow.PANEL_BORDER_GLOW), false, 3.0)
	canvas.draw_rect(rect, Color(color, DesignTokens.Glow.PANEL_BORDER_BRIGHT), false, bright_width)
