extends FoxScreen

# ==============================================================================
# settings-languages-base.gd — the language picker, as its own SCREEN (fox).
#
# The same treatment as the settings screen, and for the same reason: picking a
# language is a place the player goes to, not a dialog that floats over one. It
# wears the SAME chassis (background, header with BACK, viewport-wide footer
# band) and lays a grid of octagonal cards on the SAME plate geometry, exactly
# like faraday's LanguagesScreen.
#
# Every card shows its locale's ENDONYM — Deutsch, Русский, 日本語 — because the
# player who needs this screen is by definition the one who cannot read the
# current interface language. The locale in force keeps a lit marker dot.
#
# ── RETURN CONTRACT ──
# `Router.open_languages({languages, current, on_pick, on_back})`:
#   languages  PackedStringArray of locale codes
#   current    the locale in force
#   persist    Callable(code) — where the game stores the chosen locale
#   on_back    Callable — the door back, taken on BACK and after a pick alike
# ==============================================================================

const _Chassis := preload('res://fox/components/settings/ui/settings-chassis.gd')
const _Plate := preload('res://fox/components/settings/ui/settings-plate.gd')
const _Card := preload('res://fox/components/settings/ui/settings-language-card.gd')
const _SettingsText := preload('res://fox/components/settings/settings-text.gd')
const _ThemeData := preload('res://fox/components/settings/data/settings-theme-data.gd')

const CARD_GAP := 18.0

var theme_data: SettingsThemeData = null

var _open_options: Dictionary = {}
var _chassis = null
var _plate = null

var _nav: MenuNavigator = null
var _nav_rows: Array = []
var _nav_seeding: bool = false
var _default_input: Node = null
var _closing: bool = false

# ------------------------------------------------------------------------------

func onOpen(options = {}) -> void:
	_open_options = options if options is Dictionary else {}
	theme_data = _build_theme()
	if theme_data == null:
		theme_data = _ThemeData.new()
	_build()

func onLeave(_options = {}) -> void:
	_teardown_navigation()

func _onViewportResized() -> void:
	_rebuild()

func _build() -> void:
	_chassis = _Chassis.new()
	_chassis.build(
		self, theme_data,
		_SettingsText.resolve('settings.language.title', 'LANGUAGE'),
		_SettingsText.resolve('settings.back', 'BACK'),
		_on_back
	)
	_nav_rows = [[_chassis.back_link]]

	_plate = _Plate.new()
	_plate.theme_data = theme_data
	add_child(_plate)
	_plate.fit_into(_chassis.band)

	_build_grid()
	_setup_navigation()

func _rebuild() -> void:
	if theme_data == null:
		return
	_teardown_navigation()
	_nav_rows = []
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_plate = null
	_chassis = null
	_build()

# ------------------------------------------------------------------------------
# The grid — cards flow across the plate's content, wrapping into rows; each row
# is one navigation row, so the cursor walks the grid the way it reads.
# ------------------------------------------------------------------------------

func _build_grid() -> void:
	var codes: PackedStringArray = _open_options.get('languages', PackedStringArray())
	var current: String = str(_open_options.get('current', TranslationServer.get_locale()))

	var host: Control = _plate.left_column()
	# One column of cards, centred: the picker uses the whole plate, not the
	# settings screen's two-column split.
	_plate.right_column().visible = false
	host.alignment = BoxContainer.ALIGNMENT_CENTER
	host.add_theme_constant_override('separation', int(CARD_GAP))

	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override('h_separation', int(CARD_GAP))
	flow.add_theme_constant_override('v_separation', int(CARD_GAP))
	host.add_child(flow)

	var row: Array = []
	for code in codes:
		var card := _Card.new()
		card.theme_data = theme_data
		card.sfx = _sound_hooks()
		card.code = code
		card.endonym = _SettingsText.endonym(code)
		card.current = (code == current)
		card.picked.connect(_on_pick)
		flow.add_child(card)
		row.append(card)
		# Three per row is what the plate fits at its base width; the flow wraps on
		# its own, and the navigation grid follows the same cadence.
		if row.size() == 3:
			_nav_rows.append(row)
			row = []
	if not row.is_empty():
		_nav_rows.append(row)

# ------------------------------------------------------------------------------

# Picking applies the locale here, persists it through the caller's `persist`
# Callable (autoload-bound: the screen that opened us is already freed), then
# takes the same door as BACK — so the caller rebuilds in the chosen language.
func _on_pick(code: String) -> void:
	TranslationServer.set_locale(code)
	var persist: Variant = _open_options.get('persist')
	if persist is Callable and (persist as Callable).is_valid():
		(persist as Callable).call(code)
	_on_back()

func _on_back() -> void:
	if _closing:
		return
	_closing = true
	var on_back: Variant = _open_options.get('on_back')
	if on_back is Callable and (on_back as Callable).is_valid():
		(on_back as Callable).call()
		return
	var router: Node = get_node_or_null('/root/Router')
	if router != null and router.has_method('open_home'):
		router.open_home()

# ------------------------------------------------------------------------------
# Navigation — the same single cursor as the settings screen.
# ------------------------------------------------------------------------------

func _setup_navigation() -> void:
	if _nav_rows.is_empty():
		return
	_nav = MenuNavigator.new()
	_nav.set_rows(_nav_rows)
	_nav.set_wrap(false, true)
	_nav.set_highlight(_nav_highlight)
	_nav.set_sound(Callable())
	_nav.set_confirm(_nav_confirm)
	_attach_default_input()
	_nav_seeding = true
	_nav.seed(0, 0)
	_nav_seeding = false

func _teardown_navigation() -> void:
	if _nav != null:
		_nav.detach()
		_nav = null
	_detach_default_input()

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
		_nav_confirm()
	elif action == 'button_b':
		_on_back()

func _nav_highlight(item: Object, focused: bool) -> void:
	if item != null and item.has_method('set_navigation_focused'):
		item.set_navigation_focused(focused, _nav_seeding)

func _nav_confirm() -> void:
	if _nav == null:
		return
	var item: Object = _nav.current_item()
	if item != null and item.has_method('toggle_value'):
		item.toggle_value()

# ------------------------------------------------------------------------------
# Virtual hooks
# ------------------------------------------------------------------------------

func _build_theme() -> SettingsThemeData:
	return _ThemeData.new()

# `{select, focus, switch}` Callables the atoms tick on hover / focus / change.
func _sound_hooks() -> Dictionary:
	return {}
