class_name HexSocketDraw

# ==============================================================================
# HexSocketDraw — stateless drawing helpers for the chamfered octagon socket
# shape (8-vertex polygon, all four corners cut at 45° by `side * cut_ratio`)
# used by:
#   - HexSocket (Control popup, Settings-D) at 54px
#   - level-card-body _draw_available_q_mode ("?" socket) at 64px
#
# Geometry is delegated to `OctagonGeom.points()` so the socket shares the same
# chassis language as BeveledCard / NeonBadge / OctagonChassisDraw. The default
# cut ratio (SettingsTokens.HEX_CUT_RATIO ≈ 0.20) matches the Badge family.
#
# All helpers are static and size-parameterised. Colors are pass-through (no
# hardcoded cyan), so the same primitive draws cyan/green/gold/red sockets.
# Consumers own state (hover progress, spark time, hover flag) and pass them
# in — these helpers only paint.
#
# Promoted to fox/ so both Sylvestrine and faraday-corridors resolve the same
# HexSocketDraw by class_name. `DesignTokens.SettingsTokens` and `OctagonGeom`
# are resolved per-project via class_name (drop-in through the fox symlink).
# ==============================================================================

const SettingsTokens = DesignTokens.SettingsTokens

# Hover glow stamp. GLOW_EXTENT is how far past the socket edge the quad reaches
# (the halo used to inflate the silhouette to 1.22, plus room for the fade);
# HALO_EXTENT is where the halo actually dies. 128 px for a socket drawn at 54
# to 64: the downscale antialiases the chamfers for free.
const GLOW_STAMP_SIZE := 128
const GLOW_EXTENT := 1.30
const HALO_EXTENT := 1.22
const HALO_ALPHA := 0.21
const GLOW_PEAK := 0.38
const GLOW_FALLOFF := 1.5
const HALO_FALLOFF := 1.3

static var _GLOW_STAMPS: Dictionary = {}


# Returns the 8-vertex chamfered octagon polygon (origin at 0,0, square
# `side` x `side`). Delegates to `OctagonGeom.points` with a chamfer equal to
# `side * cut_ratio` so every consumer shares the BeveledCard / NeonBadge
# chassis language.
static func octagon_polygon(side: float, cut_ratio: float = SettingsTokens.HEX_CUT_RATIO) -> PackedVector2Array:
	return OctagonGeom.points(Rect2(0.0, 0.0, side, side), side * cut_ratio)


# Draws the full socket : optional outer halo + fill + inner ignition glow +
# hairline border. The hover_progress (0..1) drives halo, ignition and border
# alpha ramps. fill_alpha_idle/hover and border_alpha_idle/hover are explicit
# so callers can use Settings defaults or custom (cards) ramps.
static func draw_socket(
	target: CanvasItem,
	origin: Vector2,
	side: float,
	color: Color,
	hover_progress: float = 0.0,
	fill_alpha_idle: float = SettingsTokens.HEX_FILL_ALPHA,
	fill_alpha_hover: float = 0.10,
	border_alpha_idle: float = SettingsTokens.HEX_BORDER_ALPHA_IDLE,
	border_alpha_hover: float = SettingsTokens.HEX_BORDER_ALPHA_HOVER
) -> void:
	var polygon: PackedVector2Array = octagon_polygon(side)
	var translated: PackedVector2Array = _translate_polygon(polygon, origin)
	var center: Vector2 = origin + Vector2(side, side) * 0.5

	# Outer halo + inner ignition glow, in ONE textured quad (see `_glow_stamp`).
	if hover_progress > 0.0:
		_draw_glow(target, center, side, color, hover_progress)

	# Idle fill ramps to hover fill.
	var fill_alpha: float = lerp(fill_alpha_idle, fill_alpha_hover, hover_progress)
	target.draw_colored_polygon(translated, Color(color.r, color.g, color.b, fill_alpha))

	# Hairline border.
	var border_alpha: float = lerp(border_alpha_idle, border_alpha_hover, hover_progress)
	var closed: PackedVector2Array = translated.duplicate()
	closed.append(translated[0])
	target.draw_polyline(closed, Color(color.r, color.g, color.b, border_alpha), 1.0, true)


# Draws a centered icon texture inside a `side` x `side` socket positioned at
# `origin`. icon_box defaults to SettingsTokens.HEX_ICON_SIZE for legacy
# Settings sockets; callers (cards) can override.
static func draw_centered_icon(
	target: CanvasItem,
	origin: Vector2,
	side: float,
	icon_texture: Texture2D,
	color: Color,
	alpha: float = 1.0,
	icon_box: float = -1.0
) -> void:
	if icon_texture == null:
		return
	var box: float = icon_box if icon_box > 0.0 else SettingsTokens.HEX_ICON_SIZE
	var icon_size: Vector2 = Vector2(box, box)
	var center: Vector2 = origin + Vector2(side, side) * 0.5
	var icon_rect: Rect2 = Rect2(center - icon_size * 0.5, icon_size)
	target.draw_texture_rect(icon_texture, icon_rect, false, Color(color.r, color.g, color.b, alpha))


# Draws a letter-spaced label centered inside a `side` x `side` socket.
# letter_spacing is in pixels (caller converts em → px). Used for the hex-num
# slot ("01"-"99") and the "?" available marker.
static func draw_centered_label(
	target: CanvasItem,
	origin: Vector2,
	side: float,
	font: Font,
	text: String,
	color: Color,
	font_size: int,
	letter_spacing: float = 0.0
) -> void:
	if font == null or text.is_empty():
		return
	var center: Vector2 = origin + Vector2(side, side) * 0.5

	# Compute total width with letter_spacing for accurate centering.
	var total_w: float = 0.0
	var char_widths: PackedFloat32Array = PackedFloat32Array()
	for i in range(text.length()):
		var glyph: String = text.substr(i, 1)
		var glyph_w: float = font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		char_widths.append(glyph_w)
		total_w += glyph_w
	if text.length() > 1:
		total_w += letter_spacing * float(text.length() - 1)

	var ascent: float = font.get_ascent(font_size)
	var descent: float = font.get_descent(font_size)
	var baseline_y: float = center.y + (ascent - descent) * 0.5

	var pen_x: float = center.x - total_w * 0.5
	for i in range(text.length()):
		var glyph2: String = text.substr(i, 1)
		target.draw_string(font, Vector2(pen_x, baseline_y), glyph2, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		pen_x += char_widths[i]
		if i < text.length() - 1:
			pen_x += letter_spacing


# Draws the sparking dot 2px above the top vertex on a 1.2s cosine cycle
# (slotSpark animation : y 0→-4, scale 1→1.4, opacity 1→0.6 → reset).
# Caller passes accumulated spark_time and a period (default 1.2s).
static func draw_spark_dot(
	target: CanvasItem,
	origin: Vector2,
	side: float,
	color: Color,
	spark_time: float,
	period: float = SettingsTokens.HEX_SPARK_PERIOD,
	dot_size: float = SettingsTokens.HEX_SPARK_DOT_SIZE
) -> void:
	var center: Vector2 = origin + Vector2(side, side) * 0.5
	var safe_period: float = period if period > 0.0 else 1.2
	var phase: float = fposmod(spark_time, safe_period) / safe_period
	var ease: float = 0.5 - 0.5 * cos(phase * TAU) # 0 → 1 → 0
	var y_off: float = lerp(0.0, -4.0, ease)
	var scale_factor: float = lerp(1.0, 1.4, ease)
	var alpha: float = lerp(1.0, 0.6, ease)

	var dot_radius: float = dot_size * 0.5 * scale_factor
	var dot_center: Vector2 = Vector2(center.x, origin.y - 2.0 + y_off)

	# Soft halo (mirrors `box-shadow: 0 0 8px currentColor`). `Dot` rather than
	# `draw_circle`: a disc stamp batches with its neighbours, a polygon does not.
	Dot.draw(target, dot_center, dot_radius * 3.0, Color(color.r, color.g, color.b, alpha * 0.20))
	Dot.draw(target, dot_center, dot_radius * 1.8, Color(color.r, color.g, color.b, alpha * 0.45))
	# Bright core.
	Dot.draw(target, dot_center, dot_radius, Color(color.r, color.g, color.b, alpha))


# ------------------------------------------------------------------------------
# Internal helpers

static func _translate_polygon(polygon: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	if offset == Vector2.ZERO:
		return polygon
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(polygon.size())
	for i in range(polygon.size()):
		out[i] = polygon[i] + offset
	return out


# The hover glow: outer halo AND inner ignition, in a SINGLE draw call.
#
# Both used to be stacks of `draw_colored_polygon` — 3 inflated silhouettes for
# the halo, 5 shrunken ones for the ignition — rebuilt and repainted every frame
# while the hover ramp ran. A polygon opens a new batch each time, so the pair
# cost 8 draw calls per socket; a textured quad costs none of its own, batching
# with its neighbours (see `Dot`).
#
# The stamp is the composite of the two ramps, baked once per cut ratio into a
# white texture carrying the coverage in its alpha. `modulate` then supplies both
# the socket colour and the hover progress, so the whole animation is one tint of
# one quad. The visible change is that the 8 discrete steps become a continuous
# gradient.
static func _draw_glow(target: CanvasItem, center: Vector2, side: float, color: Color, hover_progress: float) -> void:
	var span: float = side * GLOW_EXTENT
	target.draw_texture_rect(
		_glow_stamp(),
		Rect2(center - Vector2(span, span) * 0.5, Vector2(span, span)),
		false,
		Color(color.r, color.g, color.b, hover_progress))


static func _glow_stamp(cut_ratio: float = SettingsTokens.HEX_CUT_RATIO) -> ImageTexture:
	if _GLOW_STAMPS.has(cut_ratio):
		return _GLOW_STAMPS[cut_ratio]
	var stamp: ImageTexture = _build_glow_stamp(cut_ratio)
	_GLOW_STAMPS[cut_ratio] = stamp
	return stamp


# `s` is the scale at which the octagon boundary passes through a pixel: 0 at the
# centre, 1 on the edge, GLOW_EXTENT at the corner of the stamp. For a chamfered
# square it is closed-form — the octagon is the intersection of |x|, |y| and the
# 45° chamfer half-planes, all homogeneous — so no polygon rasterisation is
# needed. Alphas are the source-over composite of the two ramps they replace,
# fitted to the brightness the stacks produced at full hover.
static func _build_glow_stamp(cut_ratio: float) -> ImageTexture:
	var image: Image = Image.create_empty(GLOW_STAMP_SIZE, GLOW_STAMP_SIZE, false, Image.FORMAT_RGBA8)
	var diagonal: float = 1.0 - cut_ratio
	for py in range(GLOW_STAMP_SIZE):
		for px in range(GLOW_STAMP_SIZE):
			var x: float = absf(((float(px) + 0.5) / float(GLOW_STAMP_SIZE) - 0.5) * GLOW_EXTENT)
			var y: float = absf(((float(py) + 0.5) / float(GLOW_STAMP_SIZE) - 0.5) * GLOW_EXTENT)
			var s: float = maxf(maxf(x, y) * 2.0, (x + y) / diagonal)

			var glow: float = 0.0
			if s < 1.0:
				glow = GLOW_PEAK * pow(1.0 - s, GLOW_FALLOFF)

			var halo: float = 0.0
			if s <= 1.0:
				halo = HALO_ALPHA
			elif s < HALO_EXTENT:
				halo = HALO_ALPHA * pow(1.0 - (s - 1.0) / (HALO_EXTENT - 1.0), HALO_FALLOFF)

			image.set_pixel(px, py, Color(1.0, 1.0, 1.0, 1.0 - (1.0 - halo) * (1.0 - glow)))
	return ImageTexture.create_from_image(image)
