extends Control

# ==============================================================================
# settings-volume-bar.gd — the volume slider that rides under an audio toggle
# (fox/components/settings).
#
#   ▬▬▬▬▬▬▬●──────  80%
#
# Faraday's geometry: a 40px row, a 10px track inset from the left margin, a
# round thumb at the fill edge and the percentage at the right. A gamepad nudge
# steps it by `volume_step` (0.05), the same unit the keyboard uses.
#
# It only appears when the game's binding for that channel declares a
# `volume_get` / `volume_set` pair, so a game with on/off audio never sees it.
#
# FOCUS CONTRACT (duck-typed): `set_navigation_focused`, `nudge(direction)`.
# `toggle_value()` is deliberately absent — confirming on a slider does nothing.
# ==============================================================================

const _Theme := preload('res://fox/components/settings/data/settings-theme-data.gd')

signal value_changed(value: float)

@export var initial_value: float = 0.8

var theme_data: SettingsThemeData = null

const VALUE_WIDTH := 54.0

var _value: float = 0.8
var _focused: bool = false
var _dragging: bool = false

func _ready() -> void:
	if theme_data == null:
		theme_data = _Theme.new()
	_value = clampf(initial_value, 0.0, 1.0)
	custom_minimum_size = Vector2(0, theme_data.volume_height)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_set_from_x(event.position.x)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_from_x(event.position.x)
		accept_event()

func _set_from_x(x: float) -> void:
	var span: float = maxf(1.0, _track_width())
	set_value((x - theme_data.volume_margin_left) / span)

# ── Focus contract ──

func set_navigation_focused(value: bool, _silent: bool = false) -> void:
	_focused = value
	queue_redraw()

func nudge(direction: int) -> void:
	set_value(_value + float(direction) * theme_data.volume_step)

# ── Value access ──

func get_value() -> float:
	return _value

func set_value(value: float) -> void:
	var next: float = clampf(snappedf(value, theme_data.volume_step), 0.0, 1.0)
	if is_equal_approx(next, _value):
		return
	_value = next
	queue_redraw()
	value_changed.emit(_value)

# ------------------------------------------------------------------------------

func _track_width() -> float:
	return maxf(0.0, size.x - theme_data.volume_margin_left - VALUE_WIDTH - theme_data.volume_value_gap)

func _draw() -> void:
	var accent: Color = theme_data.accent
	var width: float = _track_width()
	if width <= 0.0:
		return

	var height: float = theme_data.volume_track_height
	var left: float = theme_data.volume_margin_left
	var top: float = (size.y - height) * 0.5

	draw_rect(
		Rect2(Vector2(left, top), Vector2(width, height)),
		Color(accent, theme_data.volume_track_alpha), true
	)
	if _value > 0.0:
		draw_rect(
			Rect2(Vector2(left, top), Vector2(width * _value, height)),
			Color(accent, theme_data.volume_fill_alpha), true
		)
	draw_rect(
		Rect2(Vector2(left, top), Vector2(width, height)),
		Color(accent, 0.9 if _focused else 0.55), false, 1.0
	)

	var thumb: float = 8.0
	draw_circle(
		Vector2(left + width * _value, top + height * 0.5),
		thumb if _focused else thumb - 1.0,
		accent
	)

	var font: Font = theme_data.font_body
	if font == null:
		font = ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(size.x - VALUE_WIDTH, size.y * 0.5 + theme_data.value_size * 0.36),
		'%d%%' % int(roundf(_value * 100.0)),
		HORIZONTAL_ALIGNMENT_RIGHT, VALUE_WIDTH, theme_data.value_size,
		Color(accent, 0.9 if _focused else 0.55)
	)
