extends Control

# ==============================================================================
# settings-plate.gd — the board plate of the settings screen (fox).
#
# The body of the console sits on ONE plate, contain-fitted into the band the
# screen leaves between its header and its footer — the same chassis language
# faraday's settings screen shares with its level-select and its ladder:
#
#   ╔══════════════════════════════════╗
#   ║  audio / display …  │  credits   ║
#   ║  toggles + volumes  │  & links   ║
#   ╚══════════════════════════════════╝
#
# RESPONSIVE DOCTRINE (rules/godot-responsiveness.md): the plate is **SIZED**,
# never scaled — `size = base_size * fit` — so its octagonal edge keeps a native
# stroke width at every resolution, and the `fit` factor is carried by its single
# `content` child. `fit_into()` recomputes both.
#
# Composition surface: `left_column()`, `right_column()`.
# ==============================================================================

const _Theme := preload('res://fox/components/settings/data/settings-theme-data.gd')
const _Responsive := preload('res://fox/core/responsive.gd')
const _Link := preload('res://fox/components/settings/ui/settings-link.gd')

var theme_data: SettingsThemeData = null

var content: Control = null

var _left: VBoxContainer = null
var _right: VBoxContainer = null
var _divider: Control = null
var _fit: float = 1.0

func _ready() -> void:
	_ensure_built()

func fit() -> float:
	return _fit

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

	var band := HBoxContainer.new()
	band.name = 'columns'
	band.position = Vector2(theme_data.board_pad_x, theme_data.board_pad_y)
	band.size = theme_data.base_size - Vector2(
		theme_data.board_pad_x, theme_data.board_pad_y
	) * 2.0
	band.add_theme_constant_override('separation', int(theme_data.columns_gap))
	content.add_child(band)

	_left = VBoxContainer.new()
	_left.name = 'left'
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left.add_theme_constant_override('separation', int(theme_data.section_gap))
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
			Vector2(0.5, 8), Vector2(0.5, _divider.size.y - 8), theme_data.accent_at(0.18), 1.0
		)
	)
	band.add_child(_divider)

	_right = VBoxContainer.new()
	_right.name = 'right'
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# faraday's 1 : 1.15 split — the links column carries wider content.
	_right.size_flags_stretch_ratio = 1.15
	_right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right.alignment = BoxContainer.ALIGNMENT_CENTER
	_right.add_theme_constant_override('separation', int(theme_data.block_gap))
	band.add_child(_right)

# ------------------------------------------------------------------------------
# Composition surface
# ------------------------------------------------------------------------------

func left_column() -> VBoxContainer:
	_ensure_built()
	return _left

func right_column() -> VBoxContainer:
	_ensure_built()
	return _right

# ------------------------------------------------------------------------------
# Responsive — SIZE the plate, SCALE only its content.
# ------------------------------------------------------------------------------

func fit_into(region: Rect2) -> void:
	_ensure_built()
	var base: Vector2 = theme_data.base_size
	_fit = minf(_Responsive.contain_fit(region.size, base), theme_data.max_scale)
	content.scale = Vector2(_fit, _fit)
	size = base * _fit
	position = (region.position + (region.size - size) * 0.5).floor()
	queue_redraw()

# ------------------------------------------------------------------------------
# Chrome — the octagonal plate, at native stroke width.
# ------------------------------------------------------------------------------

func _draw() -> void:
	var shape: PackedVector2Array = _Link.octagon(
		Rect2(Vector2.ZERO, size), theme_data.board_corner
	)
	draw_colored_polygon(shape, theme_data.panel)
	var outline := shape.duplicate()
	outline.append(shape[0])
	draw_polyline(outline, theme_data.accent_at(theme_data.board_edge_alpha), 2.0)
