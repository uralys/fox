class_name OctagonChassisDraw

# ==============================================================================
# OctagonChassisDraw — frosted-glass octagonal chassis helper (stateless).
#
# Extracted from SettingsFramePanelBg so any CanvasItem (Control OR Node2D)
# can paint the exact same recipe:
#   1. A glass-blur ShaderMaterial assigned to the host (drives a white polygon
#      through DesignTokens.Glass.SHADER_PATH = card-blur.gdshader). The shader
#      replaces the polygon with the gaussian blur of the screen behind, so
#      the host canvas item must paint a WHITE octagon (no tint mixing).
#   2. A separate, material-less pass draws the dark semi-transparent tint AND
#      the neon hairline (soft 2.5px glow + crisp 1px hard line) so neither
#      goes through the blur shader.
#
# Consumers:
#   - SettingsFramePanelBg (Control popup): host owns the glass material, a
#     child `_OverlayLayer` draws the tint + hairline above the blur.
#   - LevelManifestRow (Node2D, wired by sprint Tâche 6): same recipe applied
#     to level cards; the Node2D itself receives the material and draws the
#     overlay in `_draw()` after the white polygon.
# ==============================================================================

# Builds a ShaderMaterial wired to the card-blur shader. The caller assigns the
# returned material to the CanvasItem that paints the WHITE octagon (the
# polygon color is irrelevant — the shader outputs the blurred screen behind).
static func prepare_glass_material(blur_amount: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(DesignTokens.Glass.SHADER_PATH)
	mat.set_shader_parameter('blur_amount', blur_amount)
	return mat

# Paints the white octagon polygon that the glass shader replaces with the
# blurred screen behind. `target` must own the ShaderMaterial returned by
# `prepare_glass_material()` for the blur effect to apply.
static func draw_glass_polygon(target: CanvasItem, rect: Rect2, corner: float) -> void:
	var points: PackedVector2Array = OctagonGeom.points(rect, corner)
	target.draw_colored_polygon(points, Color(1.0, 1.0, 1.0, 1.0))

# Paints the dark tint + neon hairline on top of the blurred glass. Must be
# called from a CanvasItem WITHOUT the glass material assigned (typically a
# child overlay node) so the tint and strokes stay outside the blur pass.
#
# Parameters:
#   target      — CanvasItem performing the draw (no glass material).
#   rect        — local-space rect of the chassis.
#   corner      — octagonal cut size (matches the glass polygon's corner).
#   color       — neon hue for the hairline (e.g. SettingsTokens.CYAN_PRIMARY).
#   glow_alpha  — opacity of the soft 2.5px outer glow stroke.
#   hard_alpha  — opacity of the crisp 1px inner line.
#   tint        — semi-transparent fill drawn under the strokes (e.g.
#                 SettingsTokens.PANEL_BG). Pass Color(0,0,0,0) to skip.
static func draw_tint_and_hairline(
	target: CanvasItem,
	rect: Rect2,
	corner: float,
	color: Color,
	glow_alpha: float,
	hard_alpha: float,
	tint: Color,
	width_scale: float = 1.0
) -> void:
	var points: PackedVector2Array = OctagonGeom.points(rect, corner)

	if tint.a > 0.0:
		target.draw_colored_polygon(points, tint)

	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])

	var glow_color := Color(color.r, color.g, color.b, glow_alpha)
	var hard_color := Color(color.r, color.g, color.b, hard_alpha)

	target.draw_polyline(closed, glow_color, 2.5 * width_scale, true)
	target.draw_polyline(closed, hard_color, 1.0 * width_scale, true)
