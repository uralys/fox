extends Control

# ==============================================================================
# settings-link.gd — one outbound link of a credits / social block (fox).
#
# A hexagonal socket carrying the channel's icon (or its initial when the project
# ships no icon set), tinted with the channel colour and captioned underneath —
# the generic form of faraday's HexSocket, which is what makes a row of links
# read as a row of destinations rather than a paragraph of URLs.
#
# FOCUS CONTRACT (duck-typed): `set_navigation_focused`, `toggle_value()` opens
# the URL — so gamepad confirm and mouse click take exactly the same path.
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

const SOCKET := 46.0
const CAPTION_H := 16.0

var _focused: bool = false
var _hovered: bool = false

func _ready() -> void:
	if theme_data == null:
		theme_data = _Theme.new()
	custom_minimum_size = Vector2(SOCKET + 10.0, SOCKET + CAPTION_H)
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

func _hexagon(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 6:
		var angle: float = deg_to_rad(60.0 * float(i) - 30.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _draw() -> void:
	var lit: bool = _focused or _hovered
	var center := Vector2(size.x * 0.5, SOCKET * 0.5 + 2.0)
	var hexagon := _hexagon(center, SOCKET * 0.5)

	draw_colored_polygon(hexagon, Color(color, 0.20 if lit else 0.08))
	var outline := hexagon.duplicate()
	outline.append(hexagon[0])
	draw_polyline(outline, Color(color, 1.0 if lit else 0.55), 2.0)

	if icon != null:
		var box: float = SOCKET * 0.46
		draw_texture_rect(
			icon, Rect2(center - Vector2(box, box) * 0.5, Vector2(box, box)), false,
			Color(color, 1.0 if lit else 0.8)
		)
	else:
		# No icon set shipped: the channel's initial keeps the socket legible.
		var font: Font = theme_data.font_title
		if font == null:
			font = ThemeDB.fallback_font
		var initial: String = _caption().substr(0, 1).to_upper()
		draw_string(
			font, center + Vector2(-6, 7), initial,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(color, 1.0 if lit else 0.8)
		)

	var caption_font: Font = theme_data.font_body
	if caption_font == null:
		caption_font = ThemeDB.fallback_font
	draw_string(
		caption_font, Vector2(0, size.y - 2.0), _caption(),
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 10,
		Color(color, 0.9 if lit else 0.45)
	)
