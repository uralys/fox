extends Control

# ==============================================================================
# settings-language-card.gd — one language card of the picker (fox).
#
# The octagonal card faraday's LanguagesScreen lays out in a grid, drawn with the
# SAME chassis and the SAME hover ramps as the credit sockets: idle fill at 3 %,
# hairline border at 85 %, and on hover / focus an ignition glow, a lift and a
# 1.06 scale. It carries the locale's ENDONYM — the player who needs this screen
# cannot read the current interface language.
#
# The currently applied locale keeps a filled marker dot, so the card the player
# is already on is readable without colour alone.
#
# FOCUS CONTRACT (duck-typed): `set_navigation_focused`, `toggle_value()` picks.
# ==============================================================================

const _Theme := preload('res://fox/components/settings/data/settings-theme-data.gd')

signal picked(code: String)

@export var code: String = ''
@export var endonym: String = ''
@export var current: bool = false

var theme_data: SettingsThemeData = null
var sfx: Dictionary = {}

var _hovering: bool = false
var _hover_progress: float = 0.0
var _hover_tween: Tween
var _nav_focused: bool = false

const CARD_SIZE := Vector2(196.0, 64.0)
const CARD_CUT := 12.0
const HOVER_LIFT := -3.0
const HOVER_SCALE := 1.06
const HOVER_DURATION := 0.25
const MARKER_RADIUS := 4.0

func _ready() -> void:
	if theme_data == null:
		theme_data = _Theme.new()
	custom_minimum_size = CARD_SIZE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = CARD_SIZE * 0.5
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(func() -> void: pivot_offset = size * 0.5)

func _on_mouse_entered() -> void:
	_hovering = true
	_play('select')
	_animate_hover(true)

func _on_mouse_exited() -> void:
	_hovering = false
	_animate_hover(false)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_value()
		accept_event()

# ── Focus contract ──

func set_navigation_focused(value: bool, silent: bool = false) -> void:
	if _nav_focused == value:
		return
	_nav_focused = value
	_hovering = value
	if value and not silent:
		_play('focus')
	_animate_hover(value)

func toggle_value() -> void:
	_play('switch')
	picked.emit(code)

# ------------------------------------------------------------------------------

func _play(key: String) -> void:
	var hook: Variant = sfx.get(key)
	if hook is Callable and (hook as Callable).is_valid():
		(hook as Callable).call()

func _animate_hover(active: bool) -> void:
	if not is_inside_tree():
		_set_hover_progress(1.0 if active else 0.0)
		return
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel(true) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var target_scale: float = HOVER_SCALE if active else 1.0
	_hover_tween.tween_property(self, 'scale', Vector2(target_scale, target_scale), HOVER_DURATION)
	_hover_tween.tween_method(
		_set_hover_progress, _hover_progress, 1.0 if active else 0.0, HOVER_DURATION
	)

func _set_hover_progress(value: float) -> void:
	_hover_progress = value
	queue_redraw()

func _draw() -> void:
	var accent: Color = theme_data.accent
	var lift: float = HOVER_LIFT * _hover_progress
	draw_set_transform(Vector2(0.0, lift), 0.0, Vector2.ONE)

	var shape: PackedVector2Array = OctagonGeom.points(Rect2(Vector2.ZERO, size), CARD_CUT)
	var fill_alpha: float = lerpf(theme_data.hex_fill_alpha, 0.10, _hover_progress)
	if current:
		fill_alpha = maxf(fill_alpha, 0.08)
	draw_colored_polygon(shape, Color(accent, fill_alpha))

	var closed := shape.duplicate()
	closed.append(shape[0])
	var border: float = lerpf(theme_data.hex_border_alpha_idle, 1.0, _hover_progress)
	draw_polyline(closed, Color(accent, border), 1.0, true)

	var font: Font = theme_data.font_title
	if font == null:
		font = ThemeDB.fallback_font
	var text_size: Vector2 = font.get_string_size(
		endonym, HORIZONTAL_ALIGNMENT_LEFT, -1, theme_data.label_size
	)
	var text_color: Color = Color(theme_data.text, lerpf(0.82, 1.0, _hover_progress))
	draw_string(
		font,
		Vector2((size.x - text_size.x) * 0.5, (size.y + text_size.y * 0.65) * 0.5),
		endonym, HORIZONTAL_ALIGNMENT_LEFT, -1, theme_data.label_size, text_color
	)

	# The locale in force keeps a lit marker, left of centre.
	if current:
		Dot.draw(self, Vector2(16.0, size.y * 0.5), MARKER_RADIUS, Color(accent, 1.0))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
