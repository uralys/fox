extends Control

# ==============================================================================
# settings-link.gd — one outbound link of a credits / social block (fox).
#
# The socket faraday wears: a 60px **chamfered octagon** (20 % corner cut, the
# same chassis as its badge family) carrying the channel's logo at 32px, tinted
# with the channel colour, captioned underneath. It is what makes a row of links
# read as a row of destinations rather than a paragraph of URLs.
#
# The logo comes from the shared fox icon set when the channel id names one
# (`steam`, `godot`, `bluesky`…); a game can still hand it its own texture.
#
# FOCUS CONTRACT (duck-typed): `set_navigation_focused`, `toggle_value()` opens
# the URL — gamepad confirm and mouse click take exactly the same path.
# ==============================================================================

const _Theme := preload('res://fox/components/settings/data/settings-theme-data.gd')
const _SettingsText := preload('res://fox/components/settings/settings-text.gd')

signal opened(url: String)

@export var label_key: String = ''
@export var label_text: String = ''
@export var icon: Texture2D
@export var url: String = ''
@export var color: Color = Color.WHITE

var theme_data: SettingsThemeData = null

const CAPTION_H := 18.0
const CAPTION_SIZE := 12

var _focused: bool = false
var _hovered: bool = false

func _ready() -> void:
	if theme_data == null:
		theme_data = _Theme.new()
	custom_minimum_size = Vector2(theme_data.hex_size, theme_data.hex_size + CAPTION_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = _caption()
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
	if url == '':
		return
	OS.shell_open(url)
	opened.emit(url)

# ------------------------------------------------------------------------------

func _caption() -> String:
	return _SettingsText.resolve(label_key, label_text)

# The chamfered octagon: a square with each corner cut by `hex_cut_ratio` of the
# side. Eight vertices, drawn clockwise from the top-left cut.
static func octagon(rect: Rect2, cut: float) -> PackedVector2Array:
	var left: float = rect.position.x
	var top: float = rect.position.y
	var right: float = rect.end.x
	var bottom: float = rect.end.y
	return PackedVector2Array([
		Vector2(left + cut, top), Vector2(right - cut, top),
		Vector2(right, top + cut), Vector2(right, bottom - cut),
		Vector2(right - cut, bottom), Vector2(left + cut, bottom),
		Vector2(left, bottom - cut), Vector2(left, top + cut),
	])

func _draw() -> void:
	var lit: bool = _focused or _hovered
	var side: float = theme_data.hex_size
	var rect := Rect2(Vector2((size.x - side) * 0.5, 0.0), Vector2(side, side))
	var shape: PackedVector2Array = octagon(rect, side * theme_data.hex_cut_ratio)

	draw_colored_polygon(shape, Color(color, 0.16 if lit else theme_data.hex_fill_alpha))
	var outline := shape.duplicate()
	outline.append(shape[0])
	draw_polyline(outline, Color(color, 1.0 if lit else theme_data.hex_border_alpha_idle), 2.0)

	var center: Vector2 = rect.get_center()
	var alpha: float = 1.0 if lit else theme_data.hex_border_alpha_idle
	if icon != null:
		var box: float = theme_data.hex_icon_size
		draw_texture_rect(
			icon, Rect2(center - Vector2(box, box) * 0.5, Vector2(box, box)), false,
			Color(color, alpha)
		)
	else:
		# No logo for this channel: its initial keeps the socket legible.
		var font: Font = theme_data.font_title
		if font == null:
			font = ThemeDB.fallback_font
		var initial: String = _caption().substr(0, 1).to_upper()
		var width: float = font.get_string_size(
			initial, HORIZONTAL_ALIGNMENT_LEFT, -1, theme_data.label_size
		).x
		draw_string(
			font, center + Vector2(-width * 0.5, theme_data.label_size * 0.36), initial,
			HORIZONTAL_ALIGNMENT_LEFT, -1, theme_data.label_size, Color(color, alpha)
		)

	var caption_font: Font = theme_data.font_body
	if caption_font == null:
		caption_font = ThemeDB.fallback_font
	draw_string(
		caption_font, Vector2(0, size.y - 4.0), _caption(),
		HORIZONTAL_ALIGNMENT_CENTER, size.x, CAPTION_SIZE,
		Color(color, 0.9 if lit else 0.45)
	)
