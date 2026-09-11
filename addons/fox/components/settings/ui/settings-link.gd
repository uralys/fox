extends Control

# ==============================================================================
# settings-link.gd — the channel socket of a credits / links block (fox).
#
# faraday-corridors' HexSocket, moved into fox as-is. It is a thin wrapper around
# `HexSocketDraw` (the shared fox primitive): this Control owns hover / spark
# state, input, tooltip and tweening; the fill, halo, ignition, hairline, spark
# and icon are painted by the primitive, so a socket here is pixel-identical to
# one in faraday.
#
# Behaviour
# - Idle  : faint fill (3 %), 85 % border, 85 % icon — 8-vertex octagon (corners
#           cut by side * HEX_CUT_RATIO).
# - Hover : ignition glow (radial halo inside) + drop-shadow halo outside,
#           border + icon ramp to 100 %, the socket lifts -3px and scales 1.06.
# - Spark : on hover, a small sparking dot appears above the top edge and
#           animates y / scale / opacity on a 1.2s cosine cycle.
# - Click : opens the url.
#
# FOCUS CONTRACT (duck-typed): focus lights the socket exactly like a hover, and
# `toggle_value()` opens the link — gamepad confirm and mouse click take the very
# same path.
# ==============================================================================

const _Theme := preload('res://addons/fox/components/settings/data/settings-theme-data.gd')
const _SettingsText := preload('res://addons/fox/components/settings/settings-text.gd')

signal opened(url: String)

@export var icon: Texture2D:
	set(value):
		icon = value
		queue_redraw()

@export var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()

@export var url: String = ''
@export var label_key: String = '':
	set(value):
		label_key = value
		_refresh_tooltip()
@export var label_text: String = '':
	set(value):
		label_text = value
		_refresh_tooltip()

var theme_data: SettingsThemeData = null
# Optional `{select, focus, switch}` Callables, filled by the screen.
var sfx: Dictionary = {}

var _hovering: bool = false
var _hover_progress: float = 0.0
var _spark_time: float = 0.0
var _hover_tween: Tween
var _nav_focused: bool = false

const HOVER_LIFT := -3.0
const HOVER_SCALE := 1.06
const HOVER_DURATION := 0.25
const CAPTION_HEIGHT := 18.0
const CAPTION_SIZE := 12

func _ready() -> void:
	if theme_data == null:
		theme_data = _Theme.new()
	var side: float = theme_data.hex_size
	custom_minimum_size = Vector2(side, side + CAPTION_HEIGHT)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = custom_minimum_size * 0.5

	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
		gui_input.connect(_on_gui_input)
		resized.connect(_on_resized)

	set_process(true)
	_refresh_tooltip()

func _on_resized() -> void:
	pivot_offset = size * 0.5

func _refresh_tooltip() -> void:
	tooltip_text = _caption()

func _caption() -> String:
	return _SettingsText.resolve(label_key, label_text)

func _process(delta: float) -> void:
	if _hovering:
		_spark_time += delta
		queue_redraw()

# ------------------------------------------------------------------------------
# Mouse handling

func _on_mouse_entered() -> void:
	_hovering = true
	_spark_time = 0.0
	_play('select')
	_animate_hover(true)
	queue_redraw()

func _on_mouse_exited() -> void:
	_hovering = false
	_animate_hover(false)
	queue_redraw()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_value()
		accept_event()

# ------------------------------------------------------------------------------
# Gamepad / keyboard navigation — focus lights the socket exactly like a hover.

func set_navigation_focused(value: bool, silent: bool = false) -> void:
	if _nav_focused == value:
		return
	_nav_focused = value
	_hovering = value
	if value:
		_spark_time = 0.0
		if not silent:
			_play('focus')
	_animate_hover(value)
	queue_redraw()

func toggle_value() -> void:
	_play('select')
	if url == '':
		return
	OS.shell_open(url)
	opened.emit(url)

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
	var target_progress: float = 1.0 if active else 0.0
	_hover_tween.tween_property(self, 'scale', Vector2(target_scale, target_scale), HOVER_DURATION)
	_hover_tween.tween_method(_set_hover_progress, _hover_progress, target_progress, HOVER_DURATION)

func _set_hover_progress(value: float) -> void:
	_hover_progress = value
	queue_redraw()

# ------------------------------------------------------------------------------
# Drawing — delegates to HexSocketDraw, the same primitive faraday's sockets use.

func _draw() -> void:
	var side: float = theme_data.hex_size
	var origin := Vector2((size.x - side) * 0.5, 0.0)
	var lift: float = HOVER_LIFT * _hover_progress
	draw_set_transform(Vector2(0.0, lift), 0.0, Vector2.ONE)

	HexSocketDraw.draw_socket(self, origin, side, color, _hover_progress)

	if icon != null:
		var icon_alpha: float = lerpf(
			theme_data.hex_border_alpha_idle, 1.0, _hover_progress
		)
		HexSocketDraw.draw_centered_icon(
			self, origin, side, icon, color, icon_alpha, theme_data.hex_icon_size
		)
	else:
		# No logo for this channel: its initial keeps the socket legible.
		var font: Font = theme_data.font_title
		if font == null:
			font = ThemeDB.fallback_font
		HexSocketDraw.draw_centered_label(
			self, origin, side, font, _caption().substr(0, 1).to_upper(),
			Color(color, lerpf(theme_data.hex_border_alpha_idle, 1.0, _hover_progress)),
			theme_data.label_size
		)

	if _hovering:
		HexSocketDraw.draw_spark_dot(self, origin, side, color, _spark_time)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var caption_font: Font = theme_data.font_body
	if caption_font == null:
		caption_font = ThemeDB.fallback_font
	draw_string(
		caption_font, Vector2(0, size.y - 4.0), _caption(),
		HORIZONTAL_ALIGNMENT_CENTER, size.x, CAPTION_SIZE,
		Color(color, 0.9 if (_hovering or _nav_focused) else 0.45)
	)
