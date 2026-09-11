class_name SettingsThemeData
extends Resource

# ==============================================================================
# SettingsThemeData — the ONE knob a game turns to skin the shared settings
# screen (fox/components/settings).
#
# Every metric below is the value faraday-corridors converged on for its own
# console (`DesignTokens.SettingsTokens`), so a game that touches nothing already
# wears the proven geometry: the 1060×620 board the two columns lay out in, the
# 60px octagonal sockets, the 64px option rows, the type ramp tuned for Steam Deck
# readability. A game overrides colours and fonts; it should rarely need to
# override a dimension, and when it does the token stays in ONE place.
#
# The fox atoms are drawn, not themed: each one reads this resource, so a game
# that sets four colours gets a console belonging to its art direction without
# overriding a single factory hook.
# ==============================================================================

@export_group('Palette')
# The one accent colour: plate border, section rules, toggle glow, socket edges.
@export var accent: Color = Color(0.518, 0.859, 0.855)
# Secondary accent, used for the branding socket and focus pulses.
@export var accent_alt: Color = Color(1.0, 0.0, 0.8)
# The screen's ground; the plate is a slightly lighter tint of it.
@export var background: Color = Color(0.0235, 0.0392, 0.0706)
@export var panel: Color = Color(0.0235, 0.0392, 0.0706, 0.55)
@export var text: Color = Color(0.941, 0.957, 0.973)
@export var text_dim: Color = Color(0.478, 0.510, 0.549)

@export_group('Fonts')
@export var font_title: Font
@export var font_body: Font

# ------------------------------------------------------------------------------
# Metrics — faraday's SettingsTokens, verbatim. The board is the coordinate
# system the body lays out in; it is contain-fitted into the band left between
# the header and the footer (SIZED, never scaled — its content carries the fit).
# ------------------------------------------------------------------------------

@export_group('Board')
@export var base_size: Vector2 = Vector2(1060.0, 620.0)
@export var board_pad_x: float = 34.0
@export var board_pad_y: float = 26.0
@export var board_margin_x: float = 60.0
@export var board_margin_y: float = 24.0
@export var max_scale: float = 1.4
@export var board_corner: float = 18.0
@export var board_edge_alpha: float = 0.45

@export_group('Body layout')
@export var section_gap: float = 18.0
@export var columns_gap: float = 48.0
@export var block_gap: float = 30.0
@export var block_text_gap: float = 14.0

@export_group('Socket')
@export var hex_size: float = 60.0
# 8-vertex chamfered octagon, same chassis as faraday's badge family.
@export var hex_cut_ratio: float = 0.20
@export var hex_icon_size: float = 32.0
@export var hex_gap: float = 18.0
@export var hex_border_alpha_idle: float = 0.85
@export var hex_fill_alpha: float = 0.03

@export_group('Toggle')
@export var toggle_height: float = 64.0
@export var toggle_switch_size: Vector2 = Vector2(70.0, 34.0)
@export var toggle_icon_size: float = 24.0
@export var toggle_gap_icon: float = 16.0
@export var toggle_thumb_diameter: float = 26.0
@export var toggle_track_alpha_off: float = 0.10
@export var toggle_track_alpha_on: float = 0.25
@export var toggle_border_alpha_off: float = 0.35

@export_group('Volume bar')
@export var volume_height: float = 40.0
@export var volume_margin_left: float = 12.0
@export var volume_track_height: float = 10.0
@export var volume_value_gap: float = 14.0
@export var volume_step: float = 0.05
@export var volume_track_alpha: float = 0.10
@export var volume_fill_alpha: float = 0.85

@export_group('Typography')
@export var title_size: int = 32
@export var section_size: int = 17
@export var label_size: int = 18
@export var intro_size: int = 17
@export var footer_size: int = 21
@export var version_size: int = 20
@export var value_size: int = 14

# ------------------------------------------------------------------------------
# Channel palette — the colour each well-known socket wears in faraday, so two
# games linking the same destination light it the same way.
# ------------------------------------------------------------------------------

const CHANNEL_COLORS := {
	'bluesky': Color8(95, 177, 255),
	'steam': Color8(199, 113, 182),
	'spotify': Color8(131, 225, 158),
	'artists': Color8(254, 250, 143),
	'godot': Color8(95, 177, 255),
	'fox': Color8(255, 176, 115),
	'uralys': Color8(255, 0, 204),
	'discord': Color8(114, 137, 218),
	'itch': Color8(250, 90, 90),
}

# ------------------------------------------------------------------------------
# Derived colours — one place to tune the whole console's contrast ramp.
# ------------------------------------------------------------------------------

func accent_at(alpha: float) -> Color:
	return Color(accent.r, accent.g, accent.b, alpha)

func text_at(alpha: float) -> Color:
	return Color(text.r, text.g, text.b, alpha)

func channel_color(id: String) -> Color:
	return CHANNEL_COLORS.get(id, accent)

func apply_font(target: Control, font: Font, size: int, color: Color) -> void:
	if font != null:
		target.add_theme_font_override('font', font)
	target.add_theme_font_size_override('font_size', size)
	target.add_theme_color_override('font_color', color)
