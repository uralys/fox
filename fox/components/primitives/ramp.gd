class_name Ramp
extends RefCounted

# ------------------------------------------------------------------------------
# A linear alpha gradient that does NOT cost a draw call.
#
# In the GL compatibility renderer (the one the web build runs on), a
# `draw_polygon` with per-vertex colours is a POLYGON command: it opens a NEW
# batch every single time, so seven cards drifting the same scanline cost
# fourteen draw calls. `draw_texture_rect*` is a RECT command: consecutive ones
# sharing a texture are merged into ONE instanced batch, across canvas items
# (docs/web-perf.md).
#
# A texture sampled with linear filtering IS a linear interpolation, so an N-texel
# alpha ramp stretched over the rect is identical, pixel for pixel, to the
# per-vertex gradient it replaces: interpolating a linear function linearly is
# exact. The stamp is white with the ramp in its alpha, so `modulate` carries the
# whole colour and every gradient of the game shares one texture per axis.
#
#   Ramp.draw(self, rect, color, Ramp.Edge.LEFT)   # solid at the left edge,
#                                                  # transparent at the right one
#   Ramp.draw_band(self, rect, color)              # transparent -> color -> transparent
#
# ⛔ Rectangles only. A gradient over a non-rectangular shape (the fade of
# `neon-action-button`, an octagon) still needs its per-vertex polygon.
# ------------------------------------------------------------------------------

# The edge where the gradient is at `color`, fading to fully transparent on the
# opposite one.
enum Edge { TOP, RIGHT, BOTTOM, LEFT }

# 64 texels per direction. The two directions live in ONE texture per axis,
# side by side, so a reversed gradient is a REGION: never a negative rect size,
# never a transposed draw — two flips whose exact semantics are engine internals
# no headless run can prove. The two halves touch on their opaque texels, so the
# half-texel the linear filter bleeds across the junction carries the same value
# on both sides.
const SIZE := 64

# One stamp per axis rather than one transposed both ways: two batches on a
# screen showing both (the level-select cards and its side scrims), still a
# batch instead of sixteen polygons.
static var _VERTICAL: ImageTexture
static var _HORIZONTAL: ImageTexture

static func vertical() -> ImageTexture:
	if _VERTICAL == null:
		_VERTICAL = _build(false)
	return _VERTICAL

static func horizontal() -> ImageTexture:
	if _HORIZONTAL == null:
		_HORIZONTAL = _build(true)
	return _HORIZONTAL

static func draw(canvas: CanvasItem, rect: Rect2, color: Color, solid_edge: int) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or color.a <= 0.0:
		return
	var across := solid_edge == Edge.LEFT or solid_edge == Edge.RIGHT
	# The texture rises from transparent to opaque: the solid edge is the far one
	# (BOTTOM, RIGHT) on the first half, the near one (TOP, LEFT) on the mirrored half.
	var descending := solid_edge == Edge.TOP or solid_edge == Edge.LEFT
	canvas.draw_texture_rect_region(
		horizontal() if across else vertical(),
		rect,
		_region(across, descending),
		color)

# The drifting scanline of a card or a panel: one band, opaque in the middle.
static func draw_band(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var half := rect.size.y * 0.5
	if half <= 0.0:
		return
	draw(canvas, Rect2(rect.position, Vector2(rect.size.x, half)), color, Edge.BOTTOM)
	draw(canvas, Rect2(rect.position + Vector2(0.0, half), Vector2(rect.size.x, half)), color, Edge.TOP)

static func _region(across: bool, descending: bool) -> Rect2:
	var offset := float(SIZE) if descending else 0.0
	if across:
		return Rect2(offset, 0.0, float(SIZE), 1.0)
	return Rect2(0.0, offset, 1.0, float(SIZE))

# White with the ramp in the alpha: ascending on the first half, its mirror on the
# second, so one texture serves both directions of its axis.
static func _build(across: bool) -> ImageTexture:
	var span := SIZE * 2
	var image := Image.create_empty(span if across else 1, 1 if across else span, false, Image.FORMAT_RGBA8)
	var last := float(SIZE - 1)
	for i in range(SIZE):
		var alpha := float(i) / last
		if across:
			image.set_pixel(i, 0, Color(1.0, 1.0, 1.0, alpha))
			image.set_pixel(SIZE + i, 0, Color(1.0, 1.0, 1.0, 1.0 - alpha))
		else:
			image.set_pixel(0, i, Color(1.0, 1.0, 1.0, alpha))
			image.set_pixel(0, SIZE + i, Color(1.0, 1.0, 1.0, 1.0 - alpha))
	return ImageTexture.create_from_image(image)
