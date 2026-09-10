extends FoxScreen

# ==============================================================================
# settings-screen-base.gd — the settings SCREEN of every fox game.
#
# A dedicated screen, routed like any other (`Router.open_settings()`), NOT a
# popup stacked over the game: settings is a place the player goes to, with its
# own header, its own footer and its own back door.
#
# Extended BY PATH (no class_name), like fox/core/player-base.gd: a game points
# its own `SettingsScreen` at
#   extends 'res://fox/components/settings/settings-screen-base.gd'
# and, in the common case, overrides NOTHING but `_build_layout()` and
# `_prepare_bindings()`.
#
# ── THE CHASSIS ──
#
#   ┌───────────────────────────────────────────────────────────┐
#   │ ◀ BACK            S E T T I N G S                         │ header
#   │      ╔═══════════════════════╤══════════════════════╗     │
#   │      ║ AUDIO ─────────────   │  A game by Uralys    ║     │
#   │      ║ ♪ MUSIC        (●—)   │    ⬡ ⬡ ⬡             ║     │ board plate
#   │      ║ ▬▬▬▬▬●───  70%        │  Built with …        ║     │
#   │      ╚═══════════════════════╧══════════════════════╝     │
#   │ ● v1.2.0                        🌐 Français · Privacy     │ footer bar
#   └───────────────────────────────────────────────────────────┘
#
# Header and footer span the VIEWPORT; only the plate is fitted, and it is sized
# rather than scaled (see settings-plate.gd). Every metric comes from
# `SettingsThemeData`, whose defaults are faraday's own settings tokens.
#
# ── WHAT A GAME SUPPLIES ──
#   `_build_layout()`     → a SettingsLayoutData (sections + credit blocks)
#   `_prepare_bindings()` → `id -> {get, set, volume_get?, volume_set?}` Callables,
#                            plus the reserved `language` entry `{get, set}`
#   `_build_theme()`      → a SettingsThemeData in the game's palette (optional)
# Every atom stays swappable one by one (`_make_toggle`, `_make_plate`, …), and
# the base reaches NO game autoload: Sound and Player only enter through bindings.
#
# ── RETURN CONTRACT ──
# `Router.open_settings({on_back = Callable})`. `on_back` is called once; absent
# or invalid → `Router.open_home()`.
#
# ── FOCUS CONTRACT (duck-typed) ──
# A navigable item exposes `set_navigation_focused(value, silent := false)` and
# `toggle_value()`; a slider exposes `nudge(direction)` instead of confirming.
# One MenuNavigator walks the whole screen as a ragged grid of rows.
# ==============================================================================

const _DefaultPlate := preload('res://fox/components/settings/ui/settings-plate.gd')
const _DefaultToggle := preload('res://fox/components/settings/ui/settings-toggle.gd')
const _DefaultVolumeBar := preload('res://fox/components/settings/ui/settings-volume-bar.gd')
const _DefaultSectionLabel := preload('res://fox/components/settings/ui/section-label.gd')
const _DefaultBlock := preload('res://fox/components/settings/ui/settings-block.gd')
const _DefaultFooter := preload('res://fox/components/settings/ui/settings-footer.gd')
const _TextLink := preload('res://fox/components/settings/ui/settings-text-link.gd')
const _Chassis := preload('res://fox/components/settings/ui/settings-chassis.gd')
const _SettingsText := preload('res://fox/components/settings/settings-text.gd')
const _Icons := preload('res://fox/components/settings/settings-icons.gd')
const _ThemeData := preload('res://fox/components/settings/data/settings-theme-data.gd')

# The 4-way ids of the fox input layer, mirrored rather than imported: reading
# them off `Controls` would force every consumer to resolve that autoload at
# parse time, and the screen must stay usable in a mouse-only game.
const _DIR_TOP: int = 0
const _DIR_RIGHT: int = 1
const _DIR_BOTTOM: int = 2
const _DIR_LEFT: int = 3

@export var data: Resource

# Bindings: `id -> {get, set, volume_get?, volume_set?}`, plus `language`.
var _bindings: Dictionary = {}

var theme_data: SettingsThemeData = null

# Options the screen was opened with — replayed verbatim when a language change
# rebuilds it, so the return contract survives.
var _open_options: Dictionary = {}

var _chassis = null
var _plate = null
var _footer: Control = null

# Navigation — `_nav_rows` is a ragged grid: one row per toggle, per volume bar,
# per block link row, plus the back link and the footer links.
var _nav: MenuNavigator = null
var _nav_rows: Array = []
var _nav_seeding: bool = false
var _default_input: Node = null

# The footer's language / privacy links, kept aside so they land LAST in the
# navigation grid whatever order the plate was composed in.
var _footer_links: Array = []

# Latches the single exit so a repeated B or a double-click never routes twice.
var _closing: bool = false

# ------------------------------------------------------------------------------
# Lifecycle — the fox Router calls onOpen / onLeave; FoxScreen wires the resize.
# ------------------------------------------------------------------------------

func onOpen(options = {}) -> void:
	_open_options = options if options is Dictionary else {}

	if data == null:
		data = _build_layout()
	theme_data = _build_theme()
	if theme_data == null:
		theme_data = _ThemeData.new()

	_prepare_bindings()
	_build()

func onLeave(_options = {}) -> void:
	_teardown_navigation()

func _onViewportResized() -> void:
	_rebuild()

# ------------------------------------------------------------------------------
# Build / rebuild — a resize or a locale change re-renders everything, so the
# screen is torn down and recomposed rather than walked node by node.
# ------------------------------------------------------------------------------

func _build() -> void:
	_chassis = _Chassis.new()
	_chassis.build(
		self, theme_data, _title_text(),
		_SettingsText.resolve('settings.back', 'BACK'), _on_back
	)
	# The BACK door is the first navigation row; the footer links close the list.
	_nav_rows = [[_chassis.back_link]]

	_build_footer_content()

	_plate = _make_plate()
	add_child(_plate)
	_plate.fit_into(_chassis.band)

	_compose(_plate)
	_setup_navigation()

func _rebuild() -> void:
	if theme_data == null:
		return
	_teardown_navigation()
	_nav_rows = []
	_footer_links = []
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_plate = null
	_chassis = null
	_build()

func _title_text() -> String:
	if data is SettingsLayoutData:
		return _SettingsText.resolve(data.title_key, data.title_text).to_upper()
	return ''

# ------------------------------------------------------------------------------
# Footer — the content of the chassis' bar: the build stamp on the left, the
# language switcher and privacy on the right.
# ------------------------------------------------------------------------------

func _build_footer_content() -> void:
	var layout: SettingsLayoutData = data as SettingsLayoutData
	if layout == null or _chassis == null:
		return

	var screen: Vector2 = get_viewport_rect().size
	var version: String = _version_string()
	var footer := _DefaultFooter.new()
	footer.theme_data = theme_data
	footer.version_text = (layout.version_prefix + version) if version != '' else ''
	footer.language_code = _current_language() if layout.languages.size() > 1 else ''
	footer.privacy_key = layout.privacy_key
	footer.privacy_text = layout.privacy_text
	footer.privacy_url = layout.privacy_url
	footer.language_pressed.connect(_on_language_pressed)
	footer.privacy_pressed.connect(func() -> void: OS.shell_open(layout.privacy_url))
	footer.position = Vector2(_Chassis.EDGE_MARGIN, 0)
	footer.size = Vector2(
		maxf(0.0, screen.x - _Chassis.EDGE_MARGIN * 2.0), _Chassis.FOOTER_HEIGHT
	)
	_chassis.footer_bar.add_child(footer)
	footer.build()

	_footer = footer
	_footer_links = footer.links()

# ------------------------------------------------------------------------------
# Default composition — sections left, credit blocks right.
# A game with an exotic layout overrides `_compose` and keeps everything else.
# ------------------------------------------------------------------------------

func _compose(plate) -> void:
	if plate == null or not (data is SettingsLayoutData):
		return
	var layout: SettingsLayoutData = data

	# The plate rows are inserted BEFORE the footer row registered above, so the
	# cursor walks options → links → footer in reading order.
	var plate_rows: Array = []
	var left: Control = plate.left_column()
	for section in layout.sections:
		if section != null:
			left.add_child(_build_section(section, plate_rows))

	var right: Control = plate.right_column()
	for block in layout.blocks:
		if block != null:
			right.add_child(_build_block(block, plate_rows))

	# Back link first, then the plate rows, then the footer links.
	_nav_rows.append_array(plate_rows)
	if not _footer_links.is_empty():
		_nav_rows.append(_footer_links)

# A section = its header, then each toggle, then — when the binding declares a
# volume pair — the slider that channel owns, wired to the toggle both ways.
func _build_section(section: SettingsSectionData, rows: Array) -> Control:
	var group := VBoxContainer.new()
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_theme_constant_override('separation', 0)
	group.add_child(_make_section_label(section))

	for toggle_data in section.toggles:
		if toggle_data == null:
			continue
		var toggle: Control = _make_toggle(toggle_data)
		group.add_child(toggle)
		rows.append([toggle])

		var binding: Dictionary = _bindings.get(toggle_data.id, {})
		if binding.has('volume_get'):
			var bar: Control = _make_volume_bar(binding['volume_get'], binding.get('volume_set'))
			group.add_child(bar)
			rows.append([bar])
			_wire_audio_channel(toggle, bar)

	return group

func _build_block(block: SettingsBlockData, rows: Array) -> Control:
	var node := _DefaultBlock.new()
	node.theme_data = theme_data
	node.sfx = _sound_hooks()
	node.build(block)
	var links: Array = node.links()
	if not links.is_empty():
		rows.append(links)
	return node

# Keep a channel's toggle and its slider consistent: switching off drops the bar
# to zero while remembering the audible level, switching back on restores it, and
# dragging above zero switches the toggle on. `mem` is a Dictionary so both
# closures share one mutable reference.
func _wire_audio_channel(toggle: Object, bar: Object) -> void:
	var mem := {'value': bar.initial_value}
	toggle.value_changed.connect(
		func(on: bool) -> void:
			if on:
				if bar.get_value() <= 0.0 and mem['value'] > 0.0:
					bar.set_value(mem['value'])
			else:
				bar.set_value(0.0)
	)
	bar.value_changed.connect(
		func(value: float) -> void:
			if value > 0.0:
				mem['value'] = value
				toggle.set_value(true)
	)

# ------------------------------------------------------------------------------
# Toggle binding — seed from the getter, persist through the setter.
# ------------------------------------------------------------------------------

func _bind_toggle(toggle: Object, toggle_data: SettingsToggleData) -> void:
	if toggle == null or toggle_data == null:
		return
	# A toggle that names a known option inherits the shared glyph.
	toggle.icon = toggle_data.icon if toggle_data.icon != null else _Icons.toggle(toggle_data.id)
	toggle.icon_off = toggle_data.icon_off
	toggle.icon_tint = toggle_data.icon_tint
	toggle.label_key = toggle_data.label_key
	toggle.label_text = toggle_data.label_text

	var binding: Dictionary = _bindings.get(toggle_data.id, {})
	var current_value: bool = toggle_data.default_value
	if binding.has('get'):
		current_value = bool(binding['get'].call())
	toggle.initial_value = current_value

	toggle.value_changed.connect(
		func(value: bool) -> void:
			if binding.has('set'):
				binding['set'].call(value)
	)

# ------------------------------------------------------------------------------
# Language — the picker overlays the screen (never replaces it), applies the
# locale through TranslationServer + the game's binding, then rebuilds so every
# label re-renders in the chosen language.
# ------------------------------------------------------------------------------

func _current_language() -> String:
	var binding: Dictionary = _bindings.get('language', {})
	if binding.has('get'):
		return str(binding['get'].call())
	return TranslationServer.get_locale()

# Picking a language is its own SCREEN (settings-languages-base.gd), reached
# through the router. Every Callable handed to it is bound to an AUTOLOAD, never
# to this instance: routing frees us before the picker ever calls back.
func _on_language_pressed() -> void:
	var router: Node = get_node_or_null('/root/Router')
	if router == null or not router.has_method('open_languages'):
		return
	var layout: SettingsLayoutData = data as SettingsLayoutData
	var binding: Dictionary = _bindings.get('language', {})
	router.open_languages({
		languages = layout.languages,
		current = _current_language(),
		persist = binding.get('set', Callable()),
		on_back = Callable(router, 'open_settings').bind(_open_options),
	})

# ------------------------------------------------------------------------------
# Return contract — ONE guarded exit, whatever fires it.
# ------------------------------------------------------------------------------

func _on_back() -> void:
	if _closing:
		return
	_closing = true
	var on_back: Variant = _open_options.get('on_back')
	if on_back is Callable and (on_back as Callable).is_valid():
		(on_back as Callable).call()
		return
	_open_home()

func _open_home() -> void:
	var router: Node = get_node_or_null('/root/Router')
	if router != null and router.has_method('open_home'):
		router.open_home()

# ------------------------------------------------------------------------------
# Navigation — ONE MenuNavigator over the ragged grid of rows.
# ------------------------------------------------------------------------------

func _setup_navigation() -> void:
	var rows: Array = _navigation_rows()
	if rows.is_empty():
		return

	_nav = MenuNavigator.new()
	_nav.set_rows(rows)
	_nav.set_wrap(false, true)
	_nav.set_highlight(_nav_highlight)
	_nav.set_sound(Callable())
	_nav.set_confirm(_nav_confirm)
	_nav.set_direction_interceptor(_nav_intercept)

	var signals: Array = _navigation_signals()
	if signals.size() >= 2:
		_nav.attach(signals[0], signals[1])
	else:
		_attach_default_input()

	_nav_seeding = true
	_nav.seed(0, 0)
	_nav_seeding = false

func _teardown_navigation() -> void:
	if _nav != null:
		_nav.detach()
		_nav = null
	_detach_default_input()

# Keyboard / gamepad out of the box: a game that declares the fox `Controls`
# autoload gets a navigable screen without writing an input interpreter — arrows
# and D-pad walk it, A confirms, B goes back. A game that already HAS an
# interpreter returns its own pair from `_navigation_signals()` and this never runs.
func _attach_default_input() -> void:
	var controls: Node = get_node_or_null('/root/Controls')
	if controls == null:
		return
	_default_input = controls
	controls.direction_pressed.connect(_on_default_direction)
	controls.button_pressed.connect(_on_default_button)

func _detach_default_input() -> void:
	if _default_input == null or not is_instance_valid(_default_input):
		_default_input = null
		return
	if _default_input.direction_pressed.is_connected(_on_default_direction):
		_default_input.direction_pressed.disconnect(_on_default_direction)
	if _default_input.button_pressed.is_connected(_on_default_button):
		_default_input.button_pressed.disconnect(_on_default_button)
	_default_input = null

func _on_default_direction(direction: int, _from_gamepad: bool) -> void:
	if _nav != null:
		_nav.navigate(direction)

func _on_default_button(action: String) -> void:
	if action == 'button_a':
		if _nav != null:
			_nav_confirm()
	elif action == 'button_b':
		_on_back()

func _nav_highlight(item: Object, focused: bool) -> void:
	if item != null and item.has_method('set_navigation_focused'):
		item.set_navigation_focused(focused, _nav_seeding)

func _nav_confirm() -> void:
	var item: Object = _nav.current_item()
	if item == null:
		return
	if item.has_method('toggle_value'):
		item.toggle_value()

# A slider owns the horizontal axis of its row: LEFT / RIGHT change its value
# instead of walking, which is the only way one cursor can serve both a list of
# toggles and a list of sockets.
func _nav_intercept(direction: int) -> bool:
	var item: Object = _nav.current_item()
	if item == null or not item.has_method('nudge'):
		return false
	if direction == _DIR_LEFT:
		item.nudge(-1)
		return true
	if direction == _DIR_RIGHT:
		item.nudge(1)
		return true
	return false

# ------------------------------------------------------------------------------
# Virtual hooks — the game overrides these; the defaults keep a bare game
# functional with the fox atoms.
# ------------------------------------------------------------------------------

# Where the layout resource lives when the game ships one as a `.tres`.
func _default_data_path() -> String:
	return ''

# The layout, built in code when no `.tres` is supplied. A game usually overrides
# exactly this hook: declaring sections and blocks in GDScript is cheaper than
# authoring a resource in the editor.
func _build_layout() -> Resource:
	var path: String = _default_data_path()
	if path != '':
		return load(path)
	return null

# The skin. Override to return a SettingsThemeData in the game's palette.
func _build_theme() -> SettingsThemeData:
	return _ThemeData.new()

func _prepare_bindings() -> void:
	pass

# `{select, focus, switch}` Callables the atoms tick on hover / focus / change.
# fox cannot name a game's Sound autoload, so the game hands them over here.
func _sound_hooks() -> Dictionary:
	return {}

func _make_plate() -> Control:
	var plate := _DefaultPlate.new()
	plate.theme_data = theme_data
	return plate

func _make_section_label(section: SettingsSectionData) -> Control:
	var label := _DefaultSectionLabel.new()
	label.theme_data = theme_data
	label.label_key = section.label_key
	label.label_text = section.label_text
	return label

func _make_toggle(toggle_data: SettingsToggleData) -> Control:
	var toggle := _DefaultToggle.new()
	toggle.theme_data = theme_data
	toggle.sfx = _sound_hooks()
	_bind_toggle(toggle, toggle_data)
	return toggle

func _make_volume_bar(getter: Callable, setter) -> Control:
	var bar := _DefaultVolumeBar.new()
	bar.theme_data = theme_data
	bar.sfx = _sound_hooks()
	bar.initial_value = float(getter.call())
	if setter is Callable:
		bar.value_changed.connect(setter)
	return bar

func _navigation_rows() -> Array:
	return _nav_rows

# Return `[direction_signal, tapped_signal]` from the game's input layer. Empty
# falls back to the fox `Controls` autoload (see `_attach_default_input`).
func _navigation_signals() -> Array:
	return []

# ------------------------------------------------------------------------------

# The build stamp: the game's own `G.VERSION` when it exposes one, else the
# version stamped into project.godot by fox's bundle config. Both can be absent
# (a game scaffolded without a bundle section), and an empty string is the honest
# answer — the footer then drops the stamp rather than printing `v<null>`.
func _version_string() -> String:
	var globals := get_node_or_null('/root/G')
	if globals != null and 'VERSION' in globals and globals.VERSION != null:
		return str(globals.VERSION)
	var stamped: Variant = ProjectSettings.get_setting('bundle/version', '')
	return '' if stamped == null else str(stamped)
