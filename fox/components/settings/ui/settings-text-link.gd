extends Control

# ==============================================================================
# settings-text-link.gd — a footer link of the settings view (fox).
#
#   🌐 Français        Privacy
#
# Drawn rather than a LinkButton so it carries the SAME duck-typed focus contract
# as every other navigable item of the console (`set_navigation_focused`,
# `toggle_value`): the gamepad cursor walks toggles, sockets and footer links as
# one cursor, which a stock Button cannot join.
#
# `show_globe` puts the shared globe icon left of the label — the same glyph
# faraday wears — because a language switch has to be recognisable when the
# interface is in a language the player cannot read, which is exactly the case
# they need it in.
# ==============================================================================

const _Theme := preload('res://fox/components/settings/data/settings-theme-data.gd')
const _Icons := preload('res://fox/components/settings/settings-icons.gd')

signal activated

@export var text: String = ''
@export var show_globe: bool = false

var theme_data: SettingsThemeData = null

var _focused: bool = false
var _hovered: bool = false

const GLOBE_GAP := 8.0

var _globe: Texture2D = null

func _ready() -> void:
	if theme_data == null:
		theme_data = _Theme.new()
	if show_globe:
		_globe = _Icons.globe()
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = Vector2(_measure(), float(theme_data.footer_size) + 8.0)
	mouse_entered.connect(func() -> void: _hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hovered = false; queue_redraw())

func set_text(value: String) -> void:
	text = value
	custom_minimum_size = Vector2(_measure(), float(theme_data.footer_size) + 8.0)
	queue_redraw()

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
	activated.emit()

# ------------------------------------------------------------------------------

func _font() -> Font:
	var font: Font = theme_data.font_body if theme_data != null else null
	return font if font != null else ThemeDB.fallback_font

func _measure() -> float:
	var width: float = _font().get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, theme_data.footer_size
	).x
	return width + (_globe_box() + GLOBE_GAP if show_globe else 0.0)

func _globe_box() -> float:
	return float(theme_data.footer_size) + 4.0

func _draw() -> void:
	var lit: bool = _focused or _hovered
	var color: Color = theme_data.accent_at(1.0 if lit else 0.7)
	var mid: float = size.y * 0.5
	var x: float = 0.0

	if show_globe:
		var box: float = _globe_box()
		if _globe != null:
			draw_texture_rect(
				_globe, Rect2(Vector2(0.0, mid - box * 0.5), Vector2(box, box)), false, color
			)
		else:
			var radius: float = box * 0.5
			draw_arc(Vector2(radius, mid), radius, 0.0, TAU, 24, color, 1.2)
		x += box + GLOBE_GAP

	draw_string(
		_font(), Vector2(x, mid + theme_data.footer_size * 0.36), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, theme_data.footer_size, color
	)
	if lit:
		var width: float = _font().get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, theme_data.footer_size
		).x
		draw_line(
			Vector2(x, mid + theme_data.footer_size * 0.36 + 3.0),
			Vector2(x + width, mid + theme_data.footer_size * 0.36 + 3.0),
			theme_data.accent_at(0.5), 1.0
		)
