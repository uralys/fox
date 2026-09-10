extends Control

# ==============================================================================
# settings-volume-bar.gd — the volume slider that rides under an audio toggle
# (fox/components/settings).
#
#   ▮▮▮▮▮▮▮▯▯▯   80%
#
# Segmented rather than continuous: a player reads "seven of ten" at a glance,
# and a gamepad nudge (LEFT / RIGHT on the focused row) moves exactly one segment
# — the same affordance faraday's console carries, which a bare HSlider cannot
# express without a theme.
#
# It only appears when the game's binding for that channel declares a
# `volume_get` / `volume_set` pair, so a game with on/off audio only never sees it.
#
# FOCUS CONTRACT (duck-typed): `set_navigation_focused`, `nudge(direction)`.
# `toggle_value()` is deliberately absent — confirming on a slider does nothing.
# ==============================================================================

const _Theme := preload('res://fox/components/settings/data/settings-theme-data.gd')

signal value_changed(value: float)

@export var initial_value: float = 0.8

var theme_data: SettingsThemeData = null

const SEGMENTS := 10
const ROW_HEIGHT := 26.0
const BAR_HEIGHT := 10.0
const LABEL_WIDTH := 46.0
const INDENT := 34.0

var _value: float = 0.8
var _focused: bool = false
var _dragging: bool = false

func _ready() -> void:
	if theme_data == null:
		theme_data = _Theme.new()
	_value = clampf(initial_value, 0.0, 1.0)
	custom_minimum_size = Vector2(0, ROW_HEIGHT)
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
	var span: float = maxf(1.0, _bar_width())
	var ratio: float = clampf((x - INDENT) / span, 0.0, 1.0)
	set_value(roundf(ratio * SEGMENTS) / float(SEGMENTS))

# ── Focus contract ──

func set_navigation_focused(value: bool, _silent: bool = false) -> void:
	_focused = value
	queue_redraw()

# One segment per press, the unit the bar draws in.
func nudge(direction: int) -> void:
	set_value(_value + float(direction) / float(SEGMENTS))

# ── Value access ──

func get_value() -> float:
	return _value

func set_value(value: float) -> void:
	var next: float = clampf(snappedf(value, 1.0 / float(SEGMENTS)), 0.0, 1.0)
	if is_equal_approx(next, _value):
		return
	_value = next
	queue_redraw()
	value_changed.emit(_value)

# ------------------------------------------------------------------------------

func _bar_width() -> float:
	return maxf(0.0, size.x - INDENT - LABEL_WIDTH)

func _draw() -> void:
	var accent: Color = theme_data.accent
	var width: float = _bar_width()
	if width <= 0.0:
		return

	var gap: float = 3.0
	var seg_w: float = (width - gap * float(SEGMENTS - 1)) / float(SEGMENTS)
	var top: float = (size.y - BAR_HEIGHT) * 0.5
	var filled: int = int(roundf(_value * SEGMENTS))

	for i in SEGMENTS:
		var rect := Rect2(Vector2(INDENT + float(i) * (seg_w + gap), top), Vector2(seg_w, BAR_HEIGHT))
		if i < filled:
			draw_rect(rect, Color(accent, 1.0 if _focused else 0.8), true)
		else:
			draw_rect(rect, Color(accent, 0.10), true)
			draw_rect(rect, Color(accent, 0.25), false, 1.0)

	var font: Font = theme_data.font_body
	if font == null:
		font = ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(size.x - LABEL_WIDTH + 8.0, size.y * 0.5 + theme_data.footer_size * 0.36),
		'%d%%' % int(roundf(_value * 100.0)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, theme_data.footer_size,
		Color(accent, 0.9 if _focused else 0.55)
	)
