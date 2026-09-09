class_name Dot
extends RefCounted

# ------------------------------------------------------------------------------
# A filled circle that does NOT cost a draw call.
#
# In the GL compatibility renderer (the one the web build runs on), canvas
# commands fall into two families and they do not cost the same thing:
#
#   - `draw_line`, `draw_rect`, `draw_texture*` and text are RECT/PRIMITIVE
#     commands: consecutive ones sharing a texture are merged into ONE instanced
#     batch, across canvas items;
#   - `draw_circle`, `draw_arc`, `draw_polyline`, `draw_colored_polygon`,
#     `Polygon2D` and `Line2D` are POLYGON commands, and a polygon opens a NEW
#     batch every single time. One circle, one draw call.
#
# Measured on the itch build (2026-09-08): neutralising the exit and next-step
# visuals alone, which are made of loops of `draw_circle`, took a level from 375
# to 293 draw calls. A dozen small dots per entity was the most expensive thing
# on the screen.
#
# So a dot is drawn as a TEXTURED QUAD instead: one shared antialiased white disc
# tinted by `modulate`, which lands in the batched family and merges with every
# other dot of the level, whatever the entity that emitted it.
#
#   Dot.draw(self, position, radius, color)     # was draw_circle(...)
#
# ⛔ Use it for FILLED discs only. An outline (`draw_arc` with a width) is a
# different shape and needs its own stamp; tinting a disc cannot make a ring.
# ------------------------------------------------------------------------------

# 64 px for a stamp that is drawn at 2 to 16 px: the downscale does the
# antialiasing for free, and one texture for the whole game means the batch is
# never broken by a size change.
const SIZE := 64

static var _DISC: ImageTexture

static func texture() -> ImageTexture:
	if _DISC == null:
		_DISC = _build()
	return _DISC

static func draw(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	if radius <= 0.0:
		return
	canvas.draw_texture_rect(
		texture(),
		Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)),
		false, color)

# White with the coverage in the alpha, so `modulate` carries the whole colour and
# a single stamp serves every tint in the game.
static func _build() -> ImageTexture:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var center := SIZE / 2.0
	var samples := 4
	for y in range(SIZE):
		for x in range(SIZE):
			var covered := 0.0
			for sy in range(samples):
				for sx in range(samples):
					var px := (float(x) + (float(sx) + 0.5) / samples - center) / center
					var py := (float(y) + (float(sy) + 0.5) / samples - center) / center
					if px * px + py * py <= 1.0:
						covered += 1.0
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, covered / float(samples * samples)))
	return ImageTexture.create_from_image(image)
