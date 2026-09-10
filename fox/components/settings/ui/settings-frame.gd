extends Control

# ==============================================================================
# settings-frame.gd — the DEFAULT chassis of the shared settings view (fox).
#
# It is no longer a bare PanelContainer: this is the console faraday's settings
# screen taught us, reduced to what every fox game can wear —
#
#   ┌───────────────────────────────────────────────────────────┐
#   │  SETTINGS                                             ✕   │
#   ├──────────────────────────┬────────────────────────────────┤
#   │  audio / display / …     │  credits & links blocks        │
#   │  toggles + volume bars   │  (a game by …, music, built…)  │
#   ├──────────────────────────┴────────────────────────────────┤
#   │  ● v1.2.0                        🌐 English · Privacy     │
#   └───────────────────────────────────────────────────────────┘
#
# RESPONSIVE DOCTRINE (see rules/godot-responsiveness.md): the frame is SIZED,
# never scaled — `size = base_size * fit` — so its border keeps a native stroke
# width at every resolution, and the `fit` factor is carried by the single
# `content` child. `on_viewport_resized()` recomputes both.
#
# Contract expected by the popup base (duck-typed, unchanged):
#   signal close_requested
#   add_section(control: Control)     # appends to the left column
#   on_viewport_resized()
# Extended surface used by the default composition:
#   set_title(text) / left_column() / right_column() / set_footer(control)
# ==============================================================================

const _Theme := preload('res://fox/components/settings/data/settings-theme-data.gd')
const _SettingsText := preload('res://fox/components/settings/settings-text.gd')
# Preloaded, not referenced by class_name: fox core exposes it as `FoxResponsive`
# and only some games wrap it as `Responsive`.
const _Responsive := preload('res://fox/core/responsive.gd')

signal close_requested

# The skin. Assigned by the popup base before the frame enters the tree; a frame
# built stand-alone falls back to the default holo console.
var theme_data: SettingsThemeData = null

var content: Control = null

var _title_label: Label = null
var _left: VBoxContainer = null
var _right: VBoxContainer = null
var _footer_slot: MarginContainer = null
var _divider: Control = null
var _fit: float = 1.0

const _PAD := 30.0
const _HEADER_H := 62.0
const _FOOTER_H := 46.0

func _ready() -> void:
	_ensure_built()
	on_viewport_resized()

# ------------------------------------------------------------------------------
# Build — one content tree at logical `base_size`, scaled as a block by `fit`.
# ------------------------------------------------------------------------------

func _ensure_built() -> void:
	if content != null:
		return
	if theme_data == null:
		theme_data = _Theme.new()

	mouse_filter = Control.MOUSE_FILTER_STOP

	content = Control.new()
	content.name = 'content'
	content.size = theme_data.base_size
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)

	var root := VBoxContainer.new()
	root.name = 'root'
	root.position = Vector2(_PAD, _PAD)
	root.size = theme_data.base_size - Vector2(_PAD, _PAD) * 2.0
	root.add_theme_constant_override('separation', 0)
	content.add_child(root)

	root.add_child(_build_header())
	root.add_child(_build_columns())
	root.add_child(_build_footer_slot())

func _build_header() -> Control:
	var header := Control.new()
	header.name = 'header'
	header.custom_minimum_size = Vector2(0, _HEADER_H)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_title_label = Label.new()
	_title_label.name = 'title'
	theme_data.apply_font(
		_title_label, theme_data.font_title, theme_data.title_size, theme_data.accent
	)
	_title_label.add_theme_constant_override('outline_size', 0)
	_title_label.position = Vector2(0, 6)
	header.add_child(_title_label)

	# The close affordance mirrors the game's own accent, so it reads as part of
	# the console rather than as a stray default-theme button.
	var close := Button.new()
	close.name = 'close'
	close.text = '✕'
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.size = Vector2(40, 40)
	close.position = Vector2(theme_data.base_size.x - _PAD * 2.0 - 40.0, 4)
	theme_data.apply_font(close, theme_data.font_body, 20, theme_data.accent_at(0.7))
	close.add_theme_color_override('font_hover_color', theme_data.accent)
	close.add_theme_color_override('font_pressed_color', theme_data.accent)
	close.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close)

	return header

func _build_columns() -> Control:
	var band := HBoxContainer.new()
	band.name = 'columns'
	band.size_flags_vertical = Control.SIZE_EXPAND_FILL
	band.add_theme_constant_override('separation', 28)

	_left = VBoxContainer.new()
	_left.name = 'left'
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left.add_theme_constant_override('separation', 18)
	band.add_child(_left)

	# The hairline between the two halves — drawn, so it stays one native pixel
	# wide whatever the fit (a scaled ColorRect would blur it).
	_divider = Control.new()
	_divider.name = 'divider'
	_divider.custom_minimum_size = Vector2(1, 0)
	_divider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_divider.draw.connect(func() -> void:
		_divider.draw_line(
			Vector2(0.5, 6), Vector2(0.5, _divider.size.y - 6), theme_data.accent_at(0.18), 1.0
		)
	)
	band.add_child(_divider)

	_right = VBoxContainer.new()
	_right.name = 'right'
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.size_flags_stretch_ratio = 1.1
	_right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right.alignment = BoxContainer.ALIGNMENT_CENTER
	_right.add_theme_constant_override('separation', 26)
	band.add_child(_right)

	return band

func _build_footer_slot() -> Control:
	_footer_slot = MarginContainer.new()
	_footer_slot.name = 'footer'
	_footer_slot.custom_minimum_size = Vector2(0, _FOOTER_H)
	_footer_slot.add_theme_constant_override('margin_top', 12)
	return _footer_slot

# ------------------------------------------------------------------------------
# Composition surface
# ------------------------------------------------------------------------------

func set_title(text: String) -> void:
	_ensure_built()
	_title_label.text = text

func left_column() -> VBoxContainer:
	_ensure_built()
	return _left

func right_column() -> VBoxContainer:
	_ensure_built()
	return _right

# Legacy contract kept for games composed against the previous frame: a section
# lands in the options column.
func add_section(control: Control) -> void:
	_ensure_built()
	_left.add_child(control)

func set_footer(control: Control) -> void:
	_ensure_built()
	for child in _footer_slot.get_children():
		_footer_slot.remove_child(child)
		child.queue_free()
	if control != null:
		_footer_slot.add_child(control)

# ------------------------------------------------------------------------------
# Responsive — SIZE the frame, SCALE only its content.
# ------------------------------------------------------------------------------

func on_viewport_resized() -> void:
	_ensure_built()
	var viewport: Vector2 = get_viewport_rect().size
	var base: Vector2 = theme_data.base_size
	var region: Vector2 = viewport * 0.92
	_fit = minf(_Responsive.contain_fit(region, base), theme_data.max_scale)

	content.scale = Vector2(_fit, _fit)
	size = base * _fit
	position = ((viewport - size) * 0.5).floor()
	queue_redraw()

# ------------------------------------------------------------------------------
# Chrome — panel, border and corner ticks, all at native stroke width.
# ------------------------------------------------------------------------------

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, theme_data.panel, true)
	draw_rect(rect, theme_data.accent_at(0.45), false, 2.0)

	var tick: float = 22.0
	var color: Color = theme_data.accent
	for corner in [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]:
		var sx: float = -1.0 if corner.x > 0.0 else 1.0
		var sy: float = -1.0 if corner.y > 0.0 else 1.0
		draw_line(corner, corner + Vector2(tick * sx, 0), color, 3.0)
		draw_line(corner, corner + Vector2(0, tick * sy), color, 3.0)
