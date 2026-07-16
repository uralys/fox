extends FoxPopup

# ==============================================================================
# settings-popup-base.gd — shared BEHAVIOUR of the settings popup (fox).
#
# Extended BY PATH (no class_name), exactly like fox/core/player-base.gd: each
# game points its own `SettingsPopup` at
#   extends 'res://fox/components/settings/settings-popup-base.gd'
# and keeps its own class_name + skin. The trunk captured here is everything that
# is NOT skin:
#
#   * data loading (from a game-supplied `.tres` path),
#   * a toggle-binding registry (`id -> {get, set}`) filled by `_prepare_bindings`,
#   * the `_ready` lifecycle (resolve frame → compose → wire close → arm nav),
#   * keyboard / gamepad navigation via the shared MenuNavigator,
#   * factory hooks returning the fox default atoms, overridable per game.
#
# The base is strictly skin-agnostic and reaches NO game autoload: it never names
# Controls / EventListener / Sound / Player. Those enter through hooks the game
# fills (`_navigation_signals`, `_prepare_bindings`). The frame and every atom are
# duck-typed (`_frame` is untyped on purpose) so any game skin plugs in unchanged.
#
# ── FOCUS CONTRACT (duck-typed) ──
# A navigable item (toggle / link / socket) exposes:
#   set_navigation_focused(value: bool, silent := false)   # highlight (+ tick)
#   toggle_value()                                         # confirm action
#   signal value_changed(value: bool)                      # state change
# The navigation lights items via `set_navigation_focused` (silent while seeding)
# and confirms via `toggle_value`; the per-move tick is owned by the item, so the
# navigator's own sound is disabled (parity with faraday's hand-rolled cursor).
#
# ── VIRTUAL HOOKS (override per game) ──
#   _default_data_path() -> String          fallback `.tres` when `data` unset
#   _prepare_bindings()                      fill `_bindings`
#   _compose(frame)                          add the game's sections to the frame
#   _make_frame() -> Control                 the chassis (default: fox frame)
#   _make_section_label(label_key) -> Control
#   _make_toggle(toggle_data) -> Control
#   _make_entry(entry_data) -> Control       router for novel leaf types (slider…)
#   _build_footer() -> Control
#   _navigation_items() -> Array             focusables (default: bound toggles)
#   _navigation_signals() -> Array           [direction_signal, tapped_signal]
#   _back_signal() -> Signal                 optional close signal (B / Esc)
# ==============================================================================

const _DefaultFrame := preload('res://fox/components/settings/ui/settings-frame.gd')
const _DefaultToggle := preload('res://fox/components/settings/ui/settings-toggle.gd')
const _DefaultSectionLabel := preload('res://fox/components/settings/ui/section-label.gd')
const _DefaultFooter := preload('res://fox/components/settings/ui/settings-footer.gd')

@export var data: Resource

# Toggle bindings: `id -> {get: Callable, set: Callable}`. Filled by the game's
# `_prepare_bindings`; consumed by `_bind_toggle` to seed + persist each toggle.
var _bindings: Dictionary = {}

# The composed chassis — untyped on purpose so any game frame skin duck-types in
# (`close_requested`, `add_section`, `on_viewport_resized`).
var _frame = null

# Navigation state.
var _nav: MenuNavigator = null
var _nav_focus_items: Array = []
var _nav_seeding: bool = false
var _back_connected: Signal = Signal()

# ------------------------------------------------------------------------------
# Lifecycle — resolve the frame, let the game compose its sections into it, wire
# the close signal, then arm navigation. Subclasses keep NO `_ready` of their own.
# ------------------------------------------------------------------------------

func _ready() -> void:
	if data == null:
		var path: String = _default_data_path()
		if path != '':
			data = load(path)

	_prepare_bindings()

	_frame = _make_frame()
	if _frame != null and _frame.get_parent() == null:
		add_child(_frame)
	if _frame != null:
		_frame.close_requested.connect(_on_close_requested)

	_compose(_frame)
	_setup_navigation()

func _exit_tree() -> void:
	super._exit_tree()
	_teardown_navigation()

# FoxPopup hook — keep the frame's fit scale in sync on window resize.
func _onViewportResized() -> void:
	if _frame != null and _frame.has_method('on_viewport_resized'):
		_frame.on_viewport_resized()

func _on_close_requested() -> void:
	queue_free()

# ------------------------------------------------------------------------------
# Toggle binding — set icon/label, seed from the binding getter, persist through
# the setter, and register the toggle as a focusable. Shared by every game skin;
# `toggle` is untyped so both the fox default atom and a game skin plug in.
# ------------------------------------------------------------------------------

func _bind_toggle(toggle: Object, toggle_data: SettingsToggleData) -> void:
	if toggle == null or toggle_data == null:
		return
	toggle.icon = toggle_data.icon
	toggle.label_key = toggle_data.label_key

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
	_nav_focus_items.append(toggle)

# ------------------------------------------------------------------------------
# Navigation — one MenuNavigator over the focusable column. Highlight flows through
# each item's `set_navigation_focused` (which owns its own tick, so the navigator's
# sound is a no-op); confirm flips the focused item; the first cell is seeded silently.
# ------------------------------------------------------------------------------

func _setup_navigation() -> void:
	var items: Array = _navigation_items()
	if items.is_empty():
		return

	_nav = MenuNavigator.new()
	_nav.set_column(items)
	_nav.set_wrap(false, true)
	_nav.set_highlight(_nav_highlight)
	_nav.set_sound(Callable())
	_nav.set_confirm(_nav_confirm)

	var signals: Array = _navigation_signals()
	if signals.size() >= 2:
		_nav.attach(signals[0], signals[1])

	_connect_back()

	_nav_seeding = true
	_nav.seed(0, 0)
	_nav_seeding = false

func _teardown_navigation() -> void:
	if _nav != null:
		_nav.detach()
	if not _back_connected.is_null() and _back_connected.is_connected(_on_close_requested):
		_back_connected.disconnect(_on_close_requested)

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

# ------------------------------------------------------------------------------
# Virtual hooks — the game overrides these; defaults keep a bare game functional
# with the fox disposable atoms.
# ------------------------------------------------------------------------------

func _default_data_path() -> String:
	return ''

func _prepare_bindings() -> void:
	pass

# Compose the game's sections into `frame` (untyped — duck-typed frame skin).
# The base owns lifecycle + navigation; the layout is game-specific, so this is a
# required override for any real game (the default renders nothing).
func _compose(_frame_node) -> void:
	pass

func _make_frame() -> Control:
	return _DefaultFrame.new()

func _make_section_label(label_key: String) -> Control:
	var label := _DefaultSectionLabel.new()
	label.label_key = label_key
	return label

func _make_toggle(toggle_data: SettingsToggleData) -> Control:
	var toggle := _DefaultToggle.new()
	_bind_toggle(toggle, toggle_data)
	return toggle

# Router for leaf resources with no dedicated factory (sliders, selectors…). The
# default has none — a game overrides this to map its own leaf types to atoms.
func _make_entry(_entry_data: Resource) -> Control:
	return null

func _build_footer() -> Control:
	return _DefaultFooter.new()

func _navigation_items() -> Array:
	return _nav_focus_items

# Return `[direction_signal, tapped_signal]` from the game's input layer. Empty
# disables navigation (mouse-only popup).
func _navigation_signals() -> Array:
	return []

# Optional signal that closes the popup (gamepad B / Esc). Empty = mouse-only close.
func _back_signal() -> Signal:
	return Signal()
