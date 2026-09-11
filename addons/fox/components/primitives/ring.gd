class_name Ring
extends RefCounted

# ------------------------------------------------------------------------------
# A stroked circle that does NOT cost a draw call.
#
# In the GL compatibility renderer (the one the web build runs on), canvas
# commands fall into two families and they do not cost the same thing:
#
#   - `draw_line`, `draw_rect`, `draw_texture*` and text are RECT/PRIMITIVE
#     commands: consecutive ones sharing a texture are merged into ONE instanced
#     batch, across canvas items;
#   - `draw_circle`, `draw_arc`, `draw_polyline`, `draw_colored_polygon`,
#     `Polygon2D` and `Line2D` are POLYGON commands, and a polygon opens a NEW
#     batch every single time. One arc, one draw call.
#
# `Dot` already moved the FILLED discs of the game into the batched family. A
# ring is the other half of the same problem: a leaderboard list spends 2
# `draw_arc` per avatar over 14 avatars, an exit portal 3, a rotater hub 4.
#
#   Ring.draw(self, center, radius, width, color)   # was draw_arc(center, radius,
#                                                   #   0.0, TAU, n, color, width, true)
#
# ⛔ FULL rings only. A partial sweep (`draw_arc` over less than TAU) is a
# different shape: it stays an arc, or it flattens into one `draw_multiline` the
# way the level-complete accent ring did. That rules out the 36 rim segments of
# `wheel-drawing.gd`, which are all partial.
#
# WHAT CHANGES ON SCREEN
#
# The neon stroke is the signature of the game, so the three differences are
# spelled out here, all of them measured against an idealised `draw_arc`:
#
#   1. the stamp is a TRUE circle, where `draw_arc` draws an n-gon. At
#      `point_count = 48` and radius 16 the polygon's flat sides sag 0.03 px
#      inside the circle: the stamp is the more correct of the two;
#   2. the stroke width is QUANTISED, because one texture is shared by every
#      ring of the same SHAPE. The index is `width / outer_radius` rounded to
#      1/256, so the drawn width is off by at most `outer_radius / 512`:
#      0.008 px on the 34 px leaderboard avatar, 0.011 px on the 46 px one.
#      A thin stroke on a large radius is where a coarse step would show, and
#      that is why the step is 1/256 and not 1/32;
#   3. antialiasing comes from a 4x4 supersampled downscale rather than from the
#      engine's fringe geometry, so the edge is even all the way round instead
#      of overdrawing at the polyline joints.
#
# THE STAMP IS SIZED FOR THE DRAW, and this is not an optimisation, it is the
# thing that makes the result hold up. A canvas texture is sampled BILINEARLY
# with no mipmap: a 128 px stamp squeezed into a 33 px quad takes 4 texels out
# of every 16 and aliases the stroke — measured, on the leaderboard avatar, at
# 18 % of the disc's pixels off by more than 8/255 against 5 % when the stamp is
# sized right. So the resolution is chosen per draw (`tex_of`), such that the
# ring covers about TWICE as many texels as pixels: bilinear's 2x2 tap then
# averages exactly the footprint it should. Rounded to coarse steps so that the
# several rings of ONE widget, and a whole list of those widgets, still share one
# texture — the batch is the entire point, and a resolution split gives it back.
#
# ⛔ Mipmaps do NOT solve this, they were tried: a box-filtered level smears a
# 3 px stroke into nothing, and trilinear blends two smears. Measured on the same
# avatar, one mipmapped 256 px stamp lands at 20 % of pixels off by more than
# 8/255, four times the sized stamp. The resolution ladder stays.
#
# ⛔ The SHAPE must be stable, not the colour. One texture exists per
# (resolution, quantised ratio) pair and is kept for the whole run: animating a
# stroke width against a fixed radius would mint a stamp per frame. Animate the
# TINT (free) or the radius and the width together (same ratio, same bucket).
# ------------------------------------------------------------------------------

# Two texels of empty margin so the outer antialiased edge has somewhere to fade.
# Without it the border texel is the fringe, and CLAMP repeats it outwards.
const PAD := 2

# Steps of the `width / outer_radius` ratio. 256 keeps the width error under
# `outer_radius / 512` — invisible — while still collapsing every avatar of a
# list, every ring of a portal, onto the same handful of textures.
const QUANT := 256

# Stamp resolutions, in 32 px steps between these bounds. The step is COARSE on
# purpose: the two rings of one leaderboard avatar have outer radii 3 % apart,
# and a 16 px step dropped them on 80 and 96, which is two textures and two
# batches for one widget. 32 px puts them both on 96 for the same measured error.
const TEX_STEP := 32
const TEX_MIN := 32
const TEX_MAX := 256

static var _STAMPS: Dictionary = {}

# The quantised stamp index a ring of this shape lands on. `QUANT` is a full disc
# (the stroke swallows the hole), 1 the thinnest ring the cache can hold.
static func bin_of(radius: float, width: float) -> int:
	var outer := radius + width * 0.5
	if outer <= 0.0:
		return QUANT
	return clampi(int(round(width / outer * QUANT)), 1, QUANT)

# The stamp resolution that puts ~2 texels of ring per screen pixel: the ring
# spans `tex - 2 * PAD` texels and has to cover `2 * outer` pixels.
static func tex_of(outer: float) -> int:
	var wanted := 4.0 * outer + 2.0 * PAD
	var stepped := int(round(wanted / TEX_STEP)) * TEX_STEP
	return clampi(stepped, TEX_MIN, TEX_MAX)

static func stamp(tex: int, bin: int) -> ImageTexture:
	var key := Vector2i(clampi(tex, TEX_MIN, TEX_MAX), clampi(bin, 1, QUANT))
	if not _STAMPS.has(key):
		_STAMPS[key] = _build(key.x, key.y)
	return _STAMPS[key]

static func draw(canvas: CanvasItem, center: Vector2, radius: float, width: float, color: Color) -> void:
	if radius <= 0.0 or width <= 0.0 or color.a <= 0.0:
		return
	# `draw_arc` centres its stroke ON the radius, so the shape actually covered
	# runs from `radius - width/2` to `radius + width/2`.
	var outer := radius + width * 0.5
	var tex := tex_of(outer)
	# The stamp's outer edge sits `PAD` texels inside the texture: the quad is
	# blown up by that much so the RING lands on `outer`, not the texture border.
	var half := outer * tex / (tex - 2.0 * PAD)
	canvas.draw_texture_rect(
		stamp(tex, bin_of(radius, width)),
		Rect2(center - Vector2(half, half), Vector2(half * 2.0, half * 2.0)),
		false, color)

# White with the coverage in the alpha, so `modulate` carries the whole colour and
# one stamp serves every tint of that shape in the game.
static func _build(tex: int, bin: int) -> ImageTexture:
	var image := Image.create_empty(tex, tex, false, Image.FORMAT_RGBA8)
	var center := tex * 0.5
	var r_out := tex * 0.5 - PAD
	var r_in := maxf(r_out * (1.0 - float(bin) / float(QUANT)), 0.0)
	var out_sq := r_out * r_out
	var in_sq := r_in * r_in
	var samples := 4
	for y in range(tex):
		for x in range(tex):
			var covered := 0.0
			for sy in range(samples):
				for sx in range(samples):
					var px := float(x) + (float(sx) + 0.5) / samples - center
					var py := float(y) + (float(sy) + 0.5) / samples - center
					var d_sq := px * px + py * py
					if d_sq <= out_sq and d_sq >= in_sq:
						covered += 1.0
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, covered / float(samples * samples)))
	return ImageTexture.create_from_image(image)
