class_name ControlsTestThemeData
extends Resource

# ==============================================================================
# ControlsTestThemeData — the ONE knob a game turns to skin the shared controls
# test view (fox/tools/controls-test).
#
# The view draws everything itself, so it needs a palette, two fonts and a small
# type ramp. Every field below ships a neutral default: a game that injects
# nothing still gets a readable, self-consistent training room on a dark ground.
# A game that wants the room to belong to its art direction assigns a resource of
# this type to `theme_data` before the view enters the tree, and overrides only
# the fields it cares about.
#
# The palette is organised by INPUT MEANING, never by hue: `accent_keyboard`,
# `accent_dpad`, `accent_stick_left`… so a timeline card, its gauge and its
# benchmark row stay attributable to the same physical source whatever colours a
# game picks.
# ==============================================================================

@export_group('Source accents')
# Keyboard-sourced holds, the direction cross, the timeline rule.
@export var accent_keyboard: Color = Color(0.518, 0.859, 0.855)
# D-pad-sourced holds, "engaged" rings and zones, confirmations.
@export var accent_dpad: Color = Color(0.353, 0.749, 0.443)
# Left stick: gauge, trail, L2 trigger card. Kept distinct from the right one so a
# STICK card is attributable to a side at a glance.
@export var accent_stick_left: Color = Color(0.486, 0.302, 1.0)
# Right stick: gauge, trail, R2 trigger card.
@export var accent_stick_right: Color = Color(1.0, 0.0, 0.8)

@export_group('Action accents')
# Primary action buttons (button_a / button_x on the pad vocabulary).
@export var accent_action: Color = Color(0.286, 0.612, 1.0)
# Buttons with no strong meaning of their own: shoulders, start, select, sticks.
@export var accent_neutral: Color = Color(0.75, 0.75, 0.85)
# Reset / destructive edge.
@export var accent_alert: Color = Color(1.0, 0.15, 0.15)
# Focus hold and the hysteresis band ("between release and engage").
@export var accent_focus: Color = Color(1.0, 0.85, 0.0)
# Indexed number-row actions.
@export var accent_index: Color = Color(0.996, 0.98, 0.561)

@export_group('Surfaces and text')
# Panel ground behind the gauges and the benchmark board.
@export var panel_background: Color = Color(0.039, 0.047, 0.063)
# Labels, captions, dead-zone readouts.
@export var text_secondary: Color = Color(0.478, 0.510, 0.549)
# Row keys in the metric tables.
@export var text_key: Color = Color(0.478, 0.510, 0.549)
# Row values in the metric tables.
@export var text_value: Color = Color(0.941, 0.957, 0.973)

@export_group('Fonts')
# Labels, glyphs, tabs. Falls back to the engine font when left null.
@export var font_ui: Font
# Numbers and timings. Falls back to the engine font when left null.
@export var font_body: Font

@export_group('Typography')
# Card glyph / hold timings.
@export var size_glyph: int = 25
# Card captions and per-card duration readouts.
@export var size_caption: int = 19
# Inter-press gap readout, the smallest type of the room.
@export var size_timing: int = 12

# ------------------------------------------------------------------------------
# Derived accessors — one place to resolve a null font and to tint an accent.
# ------------------------------------------------------------------------------

func ui_font() -> Font:
	return font_ui if font_ui != null else ThemeDB.fallback_font

func body_font() -> Font:
	return font_body if font_body != null else ThemeDB.fallback_font

func secondary_at(alpha: float) -> Color:
	return Color(text_secondary.r, text_secondary.g, text_secondary.b, alpha)
