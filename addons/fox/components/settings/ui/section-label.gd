extends Control

# ==============================================================================
# section-label.gd — the DEFAULT section header of the shared settings view (fox).
#
#   AUDIO ─────────────────────────────
#
# A drawn header rather than a bare Label: the trailing rule is what separates
# two stacks of toggles at a glance. Colours and font come from `theme_data`.
# ==============================================================================

const _Theme := preload('res://addons/fox/components/settings/data/settings-theme-data.gd')
const _SettingsText := preload('res://addons/fox/components/settings/settings-text.gd')

@export var label_key: String = ''
@export var label_text: String = ''

var theme_data: SettingsThemeData = null

const ROW_HEIGHT := 28.0
# faraday: SECTION_LABEL_LETTER_SPACING_EM — the wide tracking IS the signature
# of these headers, and Godot's Label cannot express it.
const TRACKING_EM := 0.32

func _ready() -> void:
	if theme_data == null:
		theme_data = _Theme.new()
	custom_minimum_size = Vector2(0, ROW_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var font: Font = theme_data.font_title
	if font == null:
		font = ThemeDB.fallback_font
	var text: String = _SettingsText.resolve(label_key, label_text).to_upper()
	var font_size: int = theme_data.section_size
	var baseline: float = size.y - 6.0
	var text_width: float = _SettingsText.draw_spaced(
		self, font, Vector2(0, baseline), text, font_size,
		theme_data.accent_at(0.85), TRACKING_EM
	)

	var rule_start: float = text_width + 14.0
	if rule_start < size.x:
		draw_line(
			Vector2(rule_start, baseline - 5.0), Vector2(size.x, baseline - 5.0),
			theme_data.accent_at(0.20), 1.0
		)
