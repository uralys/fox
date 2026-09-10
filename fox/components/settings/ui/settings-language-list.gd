extends Control

# ==============================================================================
# settings-language-list.gd — the language picker of the shared settings view (fox).
#
# A small overlay listing every locale the game declares, each shown by its
# ENDONYM (Deutsch, Русский, 日本語): the player who needs this screen is by
# definition the one who cannot read the current interface language, so the list
# never translates the names.
#
# It is an overlay inside the settings popup rather than a screen of its own —
# picking a language must not cost the player their place in the console.
# Emits `selected(code)`; clicking outside the plate emits `dismissed`.
# ==============================================================================

const _Theme := preload('res://fox/components/settings/data/settings-theme-data.gd')
const _SettingsText := preload('res://fox/components/settings/settings-text.gd')
const _TextLink := preload('res://fox/components/settings/ui/settings-text-link.gd')

signal selected(code: String)
signal dismissed

var theme_data: SettingsThemeData = null

var _plate: Control = null

const PLATE_PAD := 22.0
const ROW_GAP := 6.0

func build(codes: PackedStringArray, current: String) -> void:
	if theme_data == null:
		theme_data = _Theme.new()

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_plate = Control.new()
	_plate.name = 'plate'
	_plate.mouse_filter = Control.MOUSE_FILTER_STOP
	_plate.draw.connect(_draw_plate)
	add_child(_plate)

	var column := VBoxContainer.new()
	column.position = Vector2(PLATE_PAD, PLATE_PAD)
	column.add_theme_constant_override('separation', int(ROW_GAP))
	_plate.add_child(column)

	var width: float = 120.0
	for code in codes:
		var row := _TextLink.new()
		row.theme_data = theme_data
		row.text = _SettingsText.endonym(code) + (' ·' if code == current else '')
		var picked: String = code
		row.activated.connect(func() -> void: selected.emit(picked))
		column.add_child(row)
		width = maxf(width, row.custom_minimum_size.x)

	var height: float = float(codes.size()) * 22.0 + float(maxi(0, codes.size() - 1)) * ROW_GAP
	_plate.size = Vector2(width + PLATE_PAD * 2.0, height + PLATE_PAD * 2.0)
	_recenter()
	resized.connect(_recenter)

func _recenter() -> void:
	if _plate != null:
		_plate.position = ((size - _plate.size) * 0.5).floor()

func _gui_input(event: InputEvent) -> void:
	# A click on the scrim (never on the plate, which stops its own input) closes.
	if event is InputEventMouseButton and event.pressed:
		dismissed.emit()
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55), true)

func _draw_plate() -> void:
	var rect := Rect2(Vector2.ZERO, _plate.size)
	_plate.draw_rect(rect, theme_data.panel, true)
	_plate.draw_rect(rect, theme_data.accent_at(0.5), false, 2.0)
