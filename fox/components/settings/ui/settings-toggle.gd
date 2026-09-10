extends Control

# ==============================================================================
# settings-toggle.gd — the DEFAULT option row of the shared settings view (fox).
#
#   [icon]  MUSIC                                    ( ●———)
#
# A drawn row rather than a CheckButton: the previous default wore the stock Godot
# theme, which reads as an unfinished prototype next to any game's art direction.
# Everything here comes from `theme_data` (SettingsThemeData), so a game gets a
# console in its own palette without overriding `_make_toggle`.
#
# FOCUS CONTRACT (duck-typed, expected by the popup base's navigation):
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

const ROW_HEIGHT := 40.0
const ICON_BOX := 22.0
const TRACK := Vector2(46, 20)

func _ready() -> void:
	if theme_data == null:
		theme_data = _Theme.new()
	_value = initial_value
	custom_minimum_size = Vector2(0, ROW_HEIGHT)
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
# Draw — icon, label, pill switch. Native stroke widths (the frame carries the fit).
# ------------------------------------------------------------------------------

func _draw() -> void:
	var accent: Color = theme_data.accent
	var lit: bool = _focused or _hovered
	var mid: float = size.y * 0.5

	# Focus caret — the same "you are here" mark the gamepad cursor leaves in
	# faraday's console, so keyboard and mouse read the same row as active.
	if _focused:
		var caret := PackedVector2Array([
			Vector2(-14, mid - 5), Vector2(-7, mid), Vector2(-14, mid + 5)
		])
		draw_colored_polygon(caret, accent)

	var x: float = 0.0
	var glyph: Texture2D = icon if (_value or icon_off == null) else icon_off
	if glyph != null:
		var tint: Color = icon_tint if icon_tint.a > 0.0 else accent
		draw_texture_rect(
			glyph,
			Rect2(Vector2(x, mid - ICON_BOX * 0.5), Vector2(ICON_BOX, ICON_BOX)),
			false,
			Color(tint, 1.0 if _value else 0.35)
		)
		x += ICON_BOX + 12.0

	var font: Font = theme_data.font_body
	if font == null:
		font = ThemeDB.fallback_font
	var text: String = _SettingsText.resolve(label_key, label_text).to_upper()
	var text_color: Color = theme_data.text if _value else theme_data.text_dim
	if lit:
		text_color = accent
	draw_string(
		font, Vector2(x, mid + theme_data.label_size * 0.36), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, theme_data.label_size, text_color
	)

	_draw_switch(Vector2(size.x - TRACK.x, mid - TRACK.y * 0.5), accent)

func _draw_switch(origin: Vector2, accent: Color) -> void:
	var track := Rect2(origin, TRACK)
	var radius: float = TRACK.y * 0.5
	var on_color: Color = accent
	var off_color: Color = theme_data.text_dim

	draw_rect(track, Color(on_color, 0.22) if _value else Color(off_color, 0.12), true)
	draw_rect(track, Color(on_color, 0.8) if _value else Color(off_color, 0.5), false, 1.5)

	var knob_x: float = origin.x + (TRACK.x - radius) if _value else origin.x + radius
	draw_circle(Vector2(knob_x, origin.y + radius), radius - 3.0, on_color if _value else off_color)
