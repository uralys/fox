extends FoxPopup

# ==============================================================================
# settings-popup-base.gd — the shared settings view of every fox game.
#
# Extended BY PATH (no class_name), exactly like fox/core/player-base.gd: a game
# points its own `SettingsPopup` at
#   extends 'res://fox/components/settings/settings-popup-base.gd'
# and, in the common case, overrides NOTHING but `_prepare_bindings()` and
# `_build_layout()`.
#
# ── WHAT IT RENDERS OUT OF THE BOX ──
# The console faraday-corridors converged on, reduced to what every game shares:
#
#   ┌───────────────────────────────────────────────────────────┐
#   │  SETTINGS                                             ✕   │
#   │  AUDIO ──────────────────   │   A game by Uralys          │
#   │  ♪ MUSIC          (●——)     │      ⬡ Bluesky  ⬡ Steam     │
#   │  ▮▮▮▮▮▮▮▯▯▯  70%            │   Music by …                │
#   │  ♫ SOUNDS         (●——)     │      ⬡ Spotify              │
#   │  DISPLAY ────────────────   │   Built with …              │
#   │  ● v1.2.0                       🌐 Français · Privacy     │
#   └───────────────────────────────────────────────────────────┘
#
#   * left  — one block per `SettingsSectionData`: a header, its toggles, and a
#     volume bar under any toggle whose binding declares a `volume_get` pair;
#   * right — one block per `SettingsBlockData`: an intro line over a row of link
#     sockets (credits, socials, soundtrack, tech);
#   * footer — build stamp, language switcher (endonyms), privacy link.
#
# ── WHAT A GAME SUPPLIES ──
#   `_build_layout()`     → a SettingsLayoutData (or set `data` / `_default_data_path`)
#   `_prepare_bindings()` → `id -> {get, set, volume_get?, volume_set?}` Callables,
#                            plus the reserved `language` entry `{get, set}`
#   `_build_theme()`      → a SettingsThemeData in the game's palette (optional)
# Every atom is still swappable one by one (`_make_frame`, `_make_toggle`, …) for a
# game that outgrows the defaults, and the base reaches NO game autoload: Sound,
# Player and the input layer only enter through bindings and `_navigation_signals`.
#
# ── FOCUS CONTRACT (duck-typed) ──
# A navigable item exposes `set_navigation_focused(value, silent := false)` and
# `toggle_value()`; a slider exposes `nudge(direction)` instead of confirming.
# One MenuNavigator walks the whole console as a ragged grid of rows.
# ==============================================================================

const _DefaultFrame := preload('res://fox/components/settings/ui/settings-frame.gd')
const _DefaultToggle := preload('res://fox/components/settings/ui/settings-toggle.gd')
const _DefaultVolumeBar := preload('res://fox/components/settings/ui/settings-volume-bar.gd')
const _DefaultSectionLabel := preload('res://fox/components/settings/ui/section-label.gd')
const _DefaultBlock := preload('res://fox/components/settings/ui/settings-block.gd')
const _DefaultFooter := preload('res://fox/components/settings/ui/settings-footer.gd')
const _LanguageList := preload('res://fox/components/settings/ui/settings-language-list.gd')
const _SettingsText := preload('res://fox/components/settings/settings-text.gd')
const _ThemeData := preload('res://fox/components/settings/data/settings-theme-data.gd')

# The 4-way ids of the fox input layer, mirrored rather than imported: reading
# them off `Controls` would force every consumer to resolve that autoload at parse
# time, and the console must stay usable in a mouse-only game.
const _DIR_TOP: int = 0
const _DIR_RIGHT: int = 1
const _DIR_BOTTOM: int = 2
const _DIR_LEFT: int = 3

@export var data: Resource

# Toggle bindings: `id -> {get, set, volume_get?, volume_set?}`, plus the reserved
# `language` entry. Filled by the game's `_prepare_bindings`.
var _bindings: Dictionary = {}

# The skin every atom reads (SettingsThemeData).
var theme_data: SettingsThemeData = null

# The composed chassis — untyped on purpose so any game frame skin duck-types in
# (`close_requested`, `add_section`, `on_viewport_resized`).
var _frame = null
var _scrim: Control = null

# Navigation state — `_nav_rows` is a ragged grid: one row per toggle, per volume
# bar, per block link row, plus the footer links as the last row.
var _nav: MenuNavigator = null
var _nav_rows: Array = []
var _nav_seeding: bool = false
var _back_connected: Signal = Signal()

var _language_overlay: Control = null

# The `Controls` autoload when the console wired ITS OWN default input (see
# `_attach_default_input`); null when the game supplied an interpreter instead.
var _default_input: Node = null

# ------------------------------------------------------------------------------
# Lifecycle — full-rect scrim, frame, composition, navigation.
# ------------------------------------------------------------------------------

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if data == null:
		data = _build_layout()

	theme_data = _build_theme()
	if theme_data == null:
		theme_data = _ThemeData.new()

	_prepare_bindings()
	_build()

func _exit_tree() -> void:
	super._exit_tree()
	_teardown_navigation()

# FoxPopup hook — keep the frame's fit in sync on window resize.
func _onViewportResized() -> void:
	if _frame != null and _frame.has_method('on_viewport_resized'):
		_frame.on_viewport_resized()

func _on_close_requested() -> void:
	queue_free()

# ------------------------------------------------------------------------------
# Build / rebuild — a locale change re-renders every label, so the whole console
# is torn down and recomposed rather than walked node by node.
# ------------------------------------------------------------------------------

func _build() -> void:
	_scrim = _make_scrim()
	if _scrim != null:
		add_child(_scrim)

	_frame = _make_frame()
	if _frame != null and _frame.get_parent() == null:
		add_child(_frame)
	if _frame != null:
		_frame.close_requested.connect(_on_close_requested)
		if _frame.has_method('set_title'):
			_frame.set_title(_title_text())

	_compose(_frame)
	_setup_navigation()

func _rebuild() -> void:
	_teardown_navigation()
	_nav_rows = []
	# Detach BEFORE freeing: the new console is built in the same frame, and a
	# still-parented pending-free scrim would swallow its first clicks.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_frame = null
	_scrim = null
	_language_overlay = null
	_build()

func _title_text() -> String:
	if data is SettingsLayoutData:
		return _SettingsText.resolve(data.title_key, data.title_text).to_upper()
	return ''

# ------------------------------------------------------------------------------
# Default composition — sections left, credit blocks right, footer underneath.
# A game with an exotic layout overrides `_compose` and keeps everything else.
# ------------------------------------------------------------------------------

func _compose(frame) -> void:
	if frame == null or not (data is SettingsLayoutData):
		return
	var layout: SettingsLayoutData = data

	if frame.has_method('left_column'):
		var left: Control = frame.left_column()
		for section in layout.sections:
			if section != null:
				left.add_child(_build_section(section))

	if frame.has_method('right_column'):
		var right: Control = frame.right_column()
		for block in layout.blocks:
			if block != null:
				right.add_child(_build_block(block))

	if frame.has_method('set_footer'):
		frame.set_footer(_build_footer())

# A section = its header, then each toggle, then — when the binding declares a
# volume pair — the slider that channel owns, wired to the toggle both ways.
func _build_section(section: SettingsSectionData) -> Control:
	var group := VBoxContainer.new()
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_theme_constant_override('separation', 2)
	group.add_child(_make_section_label(section))

	for toggle_data in section.toggles:
		if toggle_data == null:
			continue
		var toggle: Control = _make_toggle(toggle_data)
		group.add_child(toggle)
		_nav_rows.append([toggle])

		var binding: Dictionary = _bindings.get(toggle_data.id, {})
		if binding.has('volume_get'):
			var bar: Control = _make_volume_bar(binding['volume_get'], binding.get('volume_set'))
			group.add_child(bar)
			_nav_rows.append([bar])
			_wire_audio_channel(toggle, bar)

	return group

func _build_block(block: SettingsBlockData) -> Control:
	var node := _DefaultBlock.new()
	node.theme_data = theme_data
	node.build(block)
	var links: Array = node.links()
	if not links.is_empty():
		_nav_rows.append(links)
	return node

func _build_footer() -> Control:
	var layout: SettingsLayoutData = data
	var footer := _DefaultFooter.new()
	footer.theme_data = theme_data
	var version: String = _version_string()
	footer.version_text = (layout.version_prefix + version) if version != '' else ''
	footer.language_code = _current_language() if layout.languages.size() > 1 else ''
	footer.privacy_key = layout.privacy_key
	footer.privacy_text = layout.privacy_text
	footer.privacy_url = layout.privacy_url
	footer.language_pressed.connect(_on_language_pressed)
	footer.privacy_pressed.connect(func() -> void: OS.shell_open(layout.privacy_url))
	footer.build()

	var links: Array = footer.links()
	if not links.is_empty():
		_nav_rows.append(links)
	return footer

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
# Toggle binding — seed from the getter, persist through the setter, and register
# the item as focusable.
# ------------------------------------------------------------------------------

func _bind_toggle(toggle: Object, toggle_data: SettingsToggleData) -> void:
	if toggle == null or toggle_data == null:
		return
	toggle.icon = toggle_data.icon
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
# Language — the picker overlays the console (never replaces it), applies the
# locale through TranslationServer + the game's binding, then rebuilds so every
# label re-renders in the chosen language.
# ------------------------------------------------------------------------------

func _current_language() -> String:
	var binding: Dictionary = _bindings.get('language', {})
	if binding.has('get'):
		return str(binding['get'].call())
	return TranslationServer.get_locale()

func _on_language_pressed() -> void:
	if _language_overlay != null:
		return
	_language_overlay = _LanguageList.new()
	_language_overlay.theme_data = theme_data
	add_child(_language_overlay)
	_language_overlay.build((data as SettingsLayoutData).languages, _current_language())
	_language_overlay.selected.connect(_on_language_selected)
	_language_overlay.dismissed.connect(_close_language_overlay)

func _close_language_overlay() -> void:
	if _language_overlay != null:
		_language_overlay.queue_free()
		_language_overlay = null

func _on_language_selected(code: String) -> void:
	_close_language_overlay()
	TranslationServer.set_locale(code)
	var binding: Dictionary = _bindings.get('language', {})
	if binding.has('set'):
		binding['set'].call(code)
	_rebuild()

# ------------------------------------------------------------------------------
# Navigation — ONE MenuNavigator over the ragged grid of rows. Highlight flows
# through each item's `set_navigation_focused`; confirm flips a toggle or opens a
# link; LEFT / RIGHT on a single-item slider row nudges it by one segment.
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
		_connect_back()
	else:
		_attach_default_input()

	_nav_seeding = true
	_nav.seed(0, 0)
	_nav_seeding = false

func _teardown_navigation() -> void:
	if _nav != null:
		_nav.detach()
		_nav = null
	if not _back_connected.is_null() and _back_connected.is_connected(_on_close_requested):
		_back_connected.disconnect(_on_close_requested)
	_detach_default_input()

# Keyboard / gamepad out of the box: a game that declares the fox `Controls`
# autoload gets a navigable console without writing an input interpreter — arrows
# and D-pad walk it, A confirms, B closes. A game that already HAS an interpreter
# returns its own pair from `_navigation_signals()` and this never runs.
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
	if _nav != null and _language_overlay == null:
		_nav.navigate(direction)

func _on_default_button(action: String) -> void:
	if _nav == null:
		return
	if action == 'button_a':
		if _language_overlay == null:
			_nav_confirm()
	elif action == 'button_b':
		if _language_overlay != null:
			_close_language_overlay()
		else:
			_on_close_requested()

func _connect_back() -> void:
	var back: Signal = _back_signal()
	if not back.is_null() and not back.is_connected(_on_close_requested):
		back.connect(_on_close_requested)
		_back_connected = back

func _nav_highlight(item: Object, focused: bool) -> void:
	if item != null and item.has_method('set_navigation_focused'):
		item.set_navigation_focused(focused, _nav_seeding)

func _nav_confirm() -> void:
	var item: Object = _nav.current_item()
	if item == null:
		return
	if item.has_method('toggle_value'):
		item.toggle_value()
	elif item.has_method('activate'):
		item.activate()

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

# The dimmed backdrop. Return null for a console that floats over a live screen.
func _make_scrim() -> Control:
	var scrim := ColorRect.new()
	scrim.name = 'scrim'
	scrim.color = Color(0, 0, 0, 0.6)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_on_close_requested()
	)
	return scrim

func _make_frame() -> Control:
	var frame := _DefaultFrame.new()
	frame.theme_data = theme_data
	return frame

func _make_section_label(section: SettingsSectionData) -> Control:
	var label := _DefaultSectionLabel.new()
	label.theme_data = theme_data
	label.label_key = section.label_key
	label.label_text = section.label_text
	return label

func _make_toggle(toggle_data: SettingsToggleData) -> Control:
	var toggle := _DefaultToggle.new()
	toggle.theme_data = theme_data
	_bind_toggle(toggle, toggle_data)
	return toggle

func _make_volume_bar(getter: Callable, setter) -> Control:
	var bar := _DefaultVolumeBar.new()
	bar.theme_data = theme_data
	bar.initial_value = float(getter.call())
	if setter is Callable:
		bar.value_changed.connect(setter)
	return bar

# Router for leaf resources with no dedicated factory (selectors, key bindings…).
func _make_entry(_entry_data: Resource) -> Control:
	return null

func _navigation_rows() -> Array:
	return _nav_rows

# Return `[direction_signal, tapped_signal]` from the game's input layer. Empty
# disables navigation (mouse-only console).
func _navigation_signals() -> Array:
	return []

# Optional signal that closes the popup (gamepad B / Esc). Empty = mouse-only close.
func _back_signal() -> Signal:
	return Signal()

# ------------------------------------------------------------------------------

# The build stamp: the game's own `G.VERSION` when it exposes one, else the
# version stamped into project.godot by fox's bundle config. Both can be absent
# (a game scaffolded without a bundle section), and an empty string is the honest
# answer — the footer then simply drops the stamp rather than printing `v<null>`.
func _version_string() -> String:
	var globals := get_node_or_null('/root/G')
	if globals != null and 'VERSION' in globals and globals.VERSION != null:
		return str(globals.VERSION)
	var stamped: Variant = ProjectSettings.get_setting('bundle/version', '')
	return '' if stamped == null else str(stamped)
