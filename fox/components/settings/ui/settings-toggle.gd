extends Control

# ==============================================================================
# settings-toggle.gd — the DEFAULT option row of the shared settings screen (fox).
#
#   [♪]  MUSIC                                  ON  ( ●———)
#
# Faraday's geometry, verbatim from its tokens: a 64px row, a 24px glyph, a
# 70×34 switch with a 26px thumb. Everything is drawn from `theme_data`, so a
# game gets a console in its own palette without overriding `_make_toggle`.
#
# FOCUS CONTRACT (duck-typed, expected by the screen base's navigation):
#   signal value_changed(value: bool)
#   set_navigation_focused(value: bool, silent := false)
#   toggle_value()
#
# `icon` / `icon_off` / `icon_tint` / `label_key` / `label_text` / `initial_value`
# are set by `_bind_toggle` on the base.
# ==============================================================================

const _Theme := preload('res://fox/components/settings/data/settings-theme-data.gd')
const _SettingsText := preload('res://fox/components/settings/settings-text.gd')

signal value_changed(value: bool)

@export var label_key: String = ''
@export var label_text: String = ''
@export var icon: Texture2D
@export var icon_off: Texture2D
@export var icon_tint: Color = Color(0, 0, 0, 0)
@export var initial_value: bool = false

var theme_data: SettingsThemeData = null

var _value: bool = false
var _focused: bool = false
var _hovered: bool = false

func _ready() -> void:
	if theme_data == null:
		theme_data = _Theme.new()
	_value = initial_value
	custom_minimum_size = Vector2(0, theme_data.toggle_height)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: _hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hovered = false; queue_redraw())

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_value()
		accept_event()

# ── Focus contract ──

func set_navigation_focused(value: bool, _silent: bool = false) -> void:
	_focused = value
	queue_redraw()

func toggle_value() -> void:
	set_value(not _value)

# ── Value access ──

func get_value() -> bool:
	return _value

func set_value(value: bool) -> void:
	if value == _value:
		return
	_value = value
	queue_redraw()
	value_changed.emit(_value)

# ------------------------------------------------------------------------------
# Draw — glyph, label, state word, switch. Native stroke widths (the plate carries
# the fit).
# ------------------------------------------------------------------------------

func _draw() -> void:
	var accent: Color = theme_data.accent
	var lit: bool = _focused or _hovered
	var mid: float = size.y * 0.5

	# Focus caret — the "you are here" mark faraday's cursor leaves, so keyboard
	# and mouse read the same row as active.
	if _focused:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-16, mid - 6), Vector2(-8, mid), Vector2(-16, mid + 6)
		]), accent)

	var x: float = 0.0
	var glyph: Texture2D = icon if (_value or icon_off == null) else icon_off
	if glyph != null:
		var box: float = theme_data.toggle_icon_size
		var tint: Color = icon_tint if icon_tint.a > 0.0 else accent
		draw_texture_rect(
			glyph, Rect2(Vector2(x, mid - box * 0.5), Vector2(box, box)), false,
			Color(tint, 1.0 if _value else 0.35)
		)
		x += box + theme_data.toggle_gap_icon

	var font: Font = theme_data.font_body
	if font == null:
		font = ThemeDB.fallback_font
	var label: String = _SettingsText.resolve(label_key, label_text).to_upper()
	var color: Color = theme_data.text if _value else theme_data.text_dim
	if lit:
		color = accent
	draw_string(
		font, Vector2(x, mid + theme_data.label_size * 0.36), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, theme_data.label_size, color
	)

	_draw_switch(
		Vector2(size.x - theme_data.toggle_switch_size.x, mid - theme_data.toggle_switch_size.y * 0.5),
		accent
	)

func _draw_switch(origin: Vector2, accent: Color) -> void:
	var track := Rect2(origin, theme_data.toggle_switch_size)
	var radius: float = theme_data.toggle_switch_size.y * 0.5
	var off: Color = theme_data.text_dim

	draw_rect(
		track,
		Color(accent, theme_data.toggle_track_alpha_on) if _value \
			else Color(off, theme_data.toggle_track_alpha_off),
		true
	)
	draw_rect(
		track,
		Color(accent, 1.0) if _value else Color(off, theme_data.toggle_border_alpha_off),
		false, 1.5
	)

	var thumb: float = theme_data.toggle_thumb_diameter * 0.5
	var travel: float = theme_data.toggle_switch_size.x - radius if _value else radius
	draw_circle(Vector2(origin.x + travel, origin.y + radius), thumb, accent if _value else off)
