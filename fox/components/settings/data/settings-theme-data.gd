class_name SettingsThemeData
extends Resource

# ==============================================================================
# SettingsThemeData — the ONE knob a game turns to skin the shared settings view
# (fox/components/settings).
#
# The fox atoms are drawn, not themed: every one of them reads its colours,
# fonts and metrics from this resource, so a game that sets four values gets a
# settings view that belongs to its art direction — without overriding a single
# factory hook. A game that wants a genuinely bespoke chassis still overrides
# `_make_frame()` / `_make_toggle()` on the popup base; this resource exists so
# that it rarely has to.
#
# Everything has a usable default (a dark holo console), so `SettingsThemeData.new()`
# is a complete theme on its own.
# ==============================================================================

@export_group('Palette')
# The one accent colour: frame border, section rules, toggle glow, link chips.
@export var accent: Color = Color(0.518, 0.859, 0.855)
# Secondary accent, used for the "on" side of a toggle track and focus pulses.
@export var accent_alt: Color = Color(1.0, 0.0, 0.8)
@export var panel: Color = Color(0.039, 0.047, 0.063, 0.96)
@export var text: Color = Color(0.941, 0.957, 0.973)
@export var text_dim: Color = Color(0.478, 0.510, 0.549)

@export_group('Fonts')
@export var font_title: Font
@export var font_body: Font

@export_group('Metrics')
# Logical size of the frame; it is contain-fitted into the viewport, never scaled
# past 1.0 (see the responsive doctrine: a frame is SIZED, its content is scaled).
@export var base_size: Vector2 = Vector2(940, 600)
@export var max_scale: float = 1.0
@export var title_size: int = 30
@export var section_size: int = 15
@export var label_size: int = 17
@export var footer_size: int = 13
@export var intro_size: int = 14

# ------------------------------------------------------------------------------
# Derived colours — one place to tune the whole console's contrast ramp.
# ------------------------------------------------------------------------------

func accent_at(alpha: float) -> Color:
	return Color(accent.r, accent.g, accent.b, alpha)

func text_at(alpha: float) -> Color:
	return Color(text.r, text.g, text.b, alpha)

func apply_font(target: Control, font: Font, size: int, color: Color) -> void:
	if font != null:
		target.add_theme_font_override('font', font)
	target.add_theme_font_size_override('font_size', size)
	target.add_theme_color_override('font_color', color)
