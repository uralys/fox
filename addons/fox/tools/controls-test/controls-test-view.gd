extends FoxScreen

# ==============================================================================
# Controls test view — the shared "training room" for the input layer.
#
# Consolidated into fox from a game that had grown it over a Steam Deck tuning
# campaign: nothing in it was ever specific to that game, and every fox game hits
# the same questions (is this hold a D-pad or a stick? how deep does L2 really
# go? how much drift does this pad have at rest?). It lives here so a game gets
# the whole room for free.
#
# Self-contained Node2D: it owns its input wiring, its entry / card / stick /
# benchmark state, its layout and all of its drawing. It paints in its own
# `_draw` and redraws on demand, so it can be a Router scene, a pane inside a
# settings screen, or a thin debug footer over a running level, with no
# dependency on any screen chrome.
#
# This script declares no global type name, on purpose: a game extends the
# component BY PATH, the fox convention for anything a game is meant to subclass.
#
#   const ControlsTest := preload('res://addons/fox/tools/controls-test/controls-test-view.gd')
#   extends ControlsTest
#
# ------------------------------------------------------------------------------
# SEAM 1 — theming
#
# Every colour, font and type size comes from a `ControlsTestThemeData` resource
# (see controls-test-theme-data.gd), never from a game's token file. The
# defaults baked into that resource already draw a readable room, so a game that
# injects nothing still works. To skin it, assign `theme_data` before the view
# enters the tree, or override `_build_theme()` in a subclass.
#
# ------------------------------------------------------------------------------
# SEAM 2 — input
#
# The base wires itself on the RAW fox `Controls` signals only
# (`direction_pressed` / `direction_released`, `stick_direction_changed`,
# `stick_moved`, `button_pressed` / `button_released`, `number_pressed`), plus
# the local raw `_input` capture that keeps each gamepad press's physical
# identity and the real axis values. It therefore knows nothing about any game's
# semantic interpretation of those events.
#
# A game that runs a semantic event layer of its own (an interpreter turning raw
# input into "focus started", "character switched"…) plugs it in by overriding
# `_semantic_signal_map()`, which returns `[]` here:
#
#   func _semantic_signal_map() -> Array:
#     return [
#       [MyEvents.focus_started, _on_focus_started],
#       [MyEvents.focus_moved, _on_focus_moved],
#     ]
#
# Each entry is a `[Signal, Callable]` pair; the base connects and disconnects
# them in lockstep with its own list, so the two passes stay symmetric by
# construction. The handlers listed above are the component's own and are meant
# to be reused. A game whose semantic layer already re-emits a raw event can trim
# the base wiring the same way, by overriding `_raw_signal_map()`.
#
# ------------------------------------------------------------------------------
# What it draws
#
# Bottom: a left-to-right history of actions, each card showing its timing (hold
# duration / inter-press gap) and its source (KB / D-PAD / L-STICK / R-STICK /
# button id). Center: a 4-way cross mirroring the latched direction, flanked by a
# LEFT-STICK and a RIGHT-STICK telemetry gauge with raw metrics (engage / release
# rings, dead / hysteresis / live zones, magnitude, angle, latched 4-way
# direction, jitter trail) and the analog L2 / R2 depth bars. A second tab runs a
# headless cadence benchmark of the same events.
#
# Sizing: the host sets `view_size` (defaults to the full viewport); the layout
# and the redraw are recomputed from it. Call `set_view_size()` on resize.
# ==============================================================================

const _ThemeData := preload('res://addons/fox/tools/controls-test/controls-test-theme-data.gd')
const _Benchmark := preload('res://addons/fox/tools/controls-test/movement-benchmark.gd')

const KIND_HOLD := 'hold'
const KIND_FOCUS := 'focus'
const KIND_FOCUS_MOVE := 'focus_move'
const KIND_TAP := 'tap'
const KIND_SWITCH := 'switch'
const KIND_RESET := 'reset'
const KIND_BACK := 'back'
const KIND_RETRIGGER := 'retrigger'
const KIND_BUTTON := 'button'
const KIND_TRIGGER := 'trigger'

# Local 4-way mirror of Controls.DIR_* — same convention (TOP=0, RIGHT=1,
# BOTTOM=2, LEFT=3). Mirrored rather than referenced because these ids index
# constant arrays at parse time, and a const that reaches into an autoload is a
# parse-time dependency this component must not carry.
const _DIR_TOP: int = 0
const _DIR_RIGHT: int = 1
const _DIR_BOTTOM: int = 2
const _DIR_LEFT: int = 3

var STICK_ENGAGE: float = Controls.STICK_ENGAGE
var STICK_RELEASE: float = Controls.STICK_RELEASE

const DIR_NAMES := ['UP', 'RIGHT', 'DOWN', 'LEFT']
const TRAIL_LEN := 26

# ------------------------------------------------------------------------------
# Theming seam
# ------------------------------------------------------------------------------

# Assign before the view enters the tree, or override _build_theme() instead.
var theme_data: _ThemeData = null

# Per-stick identity colours, resolved from the theme — left vs right get distinct
# accents so a STICK action (timeline card) and its telemetry gauge are immediately
# attributable to a side.
var _left_stick_color: Color = Color.WHITE
var _right_stick_color: Color = Color.WHITE

# Override to build the game's palette instead of assigning `theme_data`.
func _build_theme() -> _ThemeData:
	return null

func _ensure_theme() -> void:
	if theme_data == null:
		theme_data = _build_theme()
	if theme_data == null:
		theme_data = _ThemeData.new()
	_left_stick_color = theme_data.accent_stick_left
	_right_stick_color = theme_data.accent_stick_right

# ------------------------------------------------------------------------------

var _entries: Array = []
var _max_cards: int = 12

var _bench = _Benchmark.new()
const VIEWS := ['inputs', 'benchmark']
var _view: String = 'inputs'  # 'inputs' | 'benchmark'

# Footer mode (debug overlay): draw ONLY the event timeline — the same
# source-tagged cards, with no cross / stick gauge / legend — so it sits as a thin
# band over a running level without hiding the gameplay.
var footer_only: bool = false

var _current_dir: int = -1
var _current_source: String = 'KB'
var _hold_entry: Dictionary = {}
var _focus_active: bool = false
var _focus_entry: Dictionary = {}

var _flash_dir: int = -1
var _flash_t: float = 0.0

var _last_event_ms: int = 0
var _switch_frame_idx: int = -1
var _gamepad_button_frame: int = -1
var _dpad_frame: int = -1
var _stick_motion_frame: int = -1
# Set the frame a raw L2/R2 engage/release edge fires, so a semantic FOCUS card
# bound to the same trigger can swallow itself — same dedup pattern as
# _gamepad_button_frame — and the raw KIND_TRIGGER card below is the one
# physical-identity card shown, with its actual depth as a parameter.
var _trigger_frame: int = -1

# True while the analog stick owns the live hold, so a latch change closes the
# previous stick hold instead of stacking a second live card.
var _stick_hold_active: bool = false

# Raw stick state (captured from InputEventJoypadMotion, like Controls). Both
# sticks are tracked and the harder push wins, mirroring Controls' own stick
# update, so a RIGHT-stick push is tagged STICK like the left one (not mis-read as
# KB). Tracked PER DEVICE (device -> Vector2), same reasoning as Controls: multiple
# joypads can be connected (a handheld's own pad plus one or more external ones),
# and some pads even enumerate twice (native HID + XInput layer) — a single shared
# Vector2 let them fight over the same floats, which reads as a flickering gauge and
# a direction that keeps un-latching even while physically held.
var _left_stick_by_device: Dictionary = {}   # device -> Vector2
var _right_stick_by_device: Dictionary = {}  # device -> Vector2
var _left_stick: Vector2 = Vector2.ZERO   # strongest across devices, recomputed each motion event
var _right_stick: Vector2 = Vector2.ZERO  # strongest across devices, recomputed each motion event

# L2/R2 are analog too (0.0-1.0 depth), same per-device dedup reasoning as the
# sticks above — captured raw here since Controls only exposes the digital
# engage/release edge (trigger_left / trigger_right), never the live depth a gauge
# needs to render.
var _left_trigger_by_device: Dictionary = {}   # device -> float
var _right_trigger_by_device: Dictionary = {}  # device -> float
var _left_trigger: float = 0.0
var _right_trigger: float = 0.0
# Edge-detected engage/release state + live timeline card, one per side — mirrors
# Controls' own trigger hysteresis (STICK_ENGAGE / STICK_RELEASE) so the card's
# start/end matches exactly what the game itself reacts to.
var _left_trigger_down: bool = false
var _right_trigger_down: bool = false
var _left_trigger_entry: Dictionary = {}
var _right_trigger_entry: Dictionary = {}
var _left_trigger_peak: float = 0.0
var _right_trigger_peak: float = 0.0
var _stick: Vector2 = Vector2.ZERO  # dominant of the two (source-tag + benchmark)
var _left_latched_dir: int = -1
var _right_latched_dir: int = -1
var _left_trail: Array = []
var _right_trail: Array = []
var _stick_latched_dir: int = -1
var _stick_trail: Array = []
var _button_holds: Dictionary = {}
# Cross-device idempotency for raw joypad button capture — see _on_joypad_button.
var _joy_button_down: Dictionary = {}  # button_index -> true while held by any device
var _stick_engage_ms: int = 0
var _stick_last_dwell_ms: int = 0

# Host-provided render area (defaults to the full viewport).
var _size: Vector2 = Vector2.ZERO

# Layout (recomputed on resize)
var _vp: Vector2
var _card_w: float
var _card_h: float
var _gap: float
var _track_left: float
var _baseline_y: float
var _cross_center: Vector2
var _stick_center: Vector2  # benchmark single gauge
var _left_stick_center: Vector2
var _right_stick_center: Vector2
var _stick_radius: float

# ------------------------------------------------------------------------------

func _ready():
	_ensure_theme()
	if _size == Vector2.ZERO:
		_size = G.screenSize()
	_compute_layout()
	set_process(true)

# Lifecycle — the input wiring lives here (not _ready) so it is symmetric with the
# teardown: this view is often an embedded, freshly-instantiated node (a settings
# tab, a debug footer) rather than a Router scene, so onOpen / onLeave never fire
# for it. _enter_tree / _exit_tree DO — every time it enters and leaves the tree —
# which is exactly the pair the connect/disconnect must ride. We call super to keep
# FoxScreen's viewport-resize attach/detach.
func _enter_tree() -> void:
	super._enter_tree()
	_ensure_theme()
	_connect_inputs()

func _exit_tree() -> void:
	_disconnect_inputs()
	super._exit_tree()

# Router lifecycle, honoured when this view IS the routed scene. Both are no-ops
# beyond a layout refresh: the wiring rides _enter_tree / _exit_tree, which fire in
# both hosting shapes.
func onOpen(_options = {}) -> void:
	_ensure_theme()
	_compute_layout()
	queue_redraw()

func onLeave(_options = {}) -> void:
	clear_history()

# Viewport resize refresh (FoxScreen hook). A host may also drive set_view_size on
# its own `resized`, so this just recomputes the layout defensively from the
# current area.
func _onViewportResized() -> void:
	if is_inside_tree():
		_compute_layout()
		queue_redraw()

# Host hook — set the render area; recompute layout and redraw.
func set_view_size(size: Vector2) -> void:
	_size = size
	if is_inside_tree():
		_compute_layout()
		queue_redraw()

# ------------------------------------------------------------------------------

func _compute_layout():
	_vp = _size if _size != Vector2.ZERO else G.screenSize()
	_card_h = clampf(_vp.y * 0.17, 104.0, 176.0)
	_card_w = _card_h * 0.92
	_gap = _card_w * 0.22
	_track_left = _vp.x * 0.05
	_baseline_y = _vp.y - _vp.y * 0.07
	# Inputs view: LEFT STICK gauge, DIRECTION cross (center), RIGHT STICK gauge.
	_cross_center = Vector2(_vp.x * 0.5, _vp.y * 0.42)
	_left_stick_center = Vector2(_vp.x * 0.19, _vp.y * 0.42)
	_right_stick_center = Vector2(_vp.x * 0.81, _vp.y * 0.42)
	# Benchmark view keeps a single dominant-stick gauge on the right.
	_stick_center = Vector2(_vp.x * 0.63, _vp.y * 0.46)
	_stick_radius = clampf(_vp.y * 0.12, 72.0, 132.0)
	var usable = _vp.x - _track_left * 2.0 + _gap
	_max_cards = max(4, int(floor(usable / (_card_w + _gap))))
	while _entries.size() > _max_cards:
		_entries.pop_front()

# ------------------------------------------------------------------------------
# Input seams — one list per layer, each connected and disconnected in lockstep.
# ------------------------------------------------------------------------------

# The raw fox Controls wiring: the ONLY input the base knows about. Override to
# trim it when a game's own semantic layer already re-emits one of these events.
func _raw_signal_map() -> Array:
	return [
		[Controls.direction_pressed, _on_direction_pressed],
		[Controls.direction_released, _on_direction_released],
		[Controls.stick_direction_changed, _on_stick_direction_changed],
		[Controls.stick_moved, _on_stick_moved],
		[Controls.button_pressed, _on_button_pressed],
		[Controls.button_released, _on_button_released],
		[Controls.number_pressed, _on_retrigger],
	]

# The game's semantic wiring: empty here, by design. Return `[Signal, Callable]`
# pairs bound to the game's own interpreter to light up the semantic cards
# (`_on_hold_started`, `_on_tapped`, `_on_switched`, `_on_reset`, `_on_back`,
# `_on_retrigger`, `_on_focus_started`, `_on_focus_moved`, `_on_focus_confirmed`,
# `_on_focus_cancelled` are all meant to be reused).
func _semantic_signal_map() -> Array:
	return []

func _input_connections() -> Array:
	var connections: Array = _raw_signal_map().duplicate()
	connections.append_array(_semantic_signal_map())
	return connections

func _connect_inputs() -> void:
	for pair in _input_connections():
		if not pair[0].is_connected(pair[1]):
			pair[0].connect(pair[1])

func _disconnect_inputs() -> void:
	for pair in _input_connections():
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])

# ------------------------------------------------------------------------------
# Raw Controls handlers
# ------------------------------------------------------------------------------

func _on_direction_pressed(direction: int, from_gamepad: bool) -> void:
	if from_gamepad:
		_dpad_frame = Engine.get_process_frames()
	_on_hold_started(direction)

func _on_direction_released(_direction: int, from_gamepad: bool) -> void:
	_on_hold_ended(from_gamepad)

# The analog stick reaches the timeline as a hold too: Controls latches the
# dominant 4-way after hysteresis and emits -1 on release, which is exactly the
# press / release pair a card needs.
func _on_stick_direction_changed(direction: int, _magnitude: float) -> void:
	if direction == -1:
		if _stick_hold_active:
			_stick_hold_active = false
			_on_hold_ended(true)
		return
	_stick_motion_frame = Engine.get_process_frames()
	if _stick_hold_active:
		_on_hold_ended(true)
	_stick_hold_active = true
	_on_hold_started(direction)

# The per-device axis truth is captured in _input below (Controls only forwards the
# dominant vector), so this is a redraw tick, not a state source.
func _on_stick_moved(_vector: Vector2) -> void:
	queue_redraw()

# Controls names buttons by physical POSITION, never by game meaning, so this
# mapping is the same on every pad brand and on the keyboard keys folded onto them.
func _on_button_pressed(action: String) -> void:
	match action:
		'button_a': _on_tapped()
		'button_x': _on_switched()
		'button_y': _on_reset()
		'button_b': _on_back()
		'trigger_left': _on_focus_started()

func _on_button_released(action: String) -> void:
	if action == 'trigger_left':
		_on_focus_ended()

# ------------------------------------------------------------------------------
# Raw gamepad capture (buttons + sticks) — keeps physical identity & axis values.
# ------------------------------------------------------------------------------

func _input(event):
	if event is InputEventJoypadButton:
		_on_joypad_button(event)
	elif event is InputEventJoypadMotion:
		_on_joypad_motion(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		# Page Up/Down navigate the tabs on a keyboard (the shoulders do it on a pad).
		if event.keycode == KEY_PAGEUP:
			_select_view(-1)
		elif event.keycode == KEY_PAGEDOWN:
			_select_view(1)

# Move the active tab by `delta` (clamped — INPUTS to BENCHMARK).
func _select_view(delta: int) -> void:
	var idx = VIEWS.find(_view)
	if idx == -1:
		idx = 0
	var new_view = VIEWS[clampi(idx + delta, 0, VIEWS.size() - 1)]
	if new_view == _view:
		return
	_view = new_view
	queue_redraw()

func _joy_button_name(b: int) -> String:
	match b:
		JOY_BUTTON_A: return 'A'
		JOY_BUTTON_B: return 'B'
		JOY_BUTTON_X: return 'X'
		JOY_BUTTON_Y: return 'Y'
		JOY_BUTTON_LEFT_SHOULDER: return 'LB'
		JOY_BUTTON_RIGHT_SHOULDER: return 'RB'
		JOY_BUTTON_START: return 'START'
		JOY_BUTTON_BACK: return 'SELECT'
		JOY_BUTTON_LEFT_STICK: return 'L3'
		JOY_BUTTON_RIGHT_STICK: return 'R3'
		JOY_BUTTON_DPAD_UP: return 'DPAD_UP'
		JOY_BUTTON_DPAD_DOWN: return 'DPAD_DOWN'
		JOY_BUTTON_DPAD_LEFT: return 'DPAD_LEFT'
		JOY_BUTTON_DPAD_RIGHT: return 'DPAD_RIGHT'
	return 'BTN_%d' % b

func _on_joypad_button(event: InputEventJoypadButton):
	var b = event.button_index
	# Raw capture reads every connected device — a pad that enumerates twice (native
	# HID + XInput layer) mirrors the same press on both, which would otherwise
	# double-push a timeline card / double-toggle the view per single physical press.
	# Same idempotent-hold guard as Controls, kept local since this view
	# intentionally bypasses Controls for raw capture.
	if event.pressed:
		if _joy_button_down.get(b, false):
			return
		_joy_button_down[b] = true
	else:
		if not _joy_button_down.get(b, false):
			return
		_joy_button_down.erase(b)
	# Y toggles the view (INPUTS to BENCHMARK). Mark the frame so the semantic reset
	# that a bare Y also emits is swallowed: here Y is a screen control, not a metrics
	# reset (the keyboard R keeps that).
	if b == JOY_BUTTON_Y:
		if event.pressed:
			_view = 'benchmark' if _view == 'inputs' else 'inputs'
			_gamepad_button_frame = Engine.get_process_frames()
		return
	if b in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		if event.pressed:
			_dpad_frame = Engine.get_process_frames()
		return
	# The shoulders are the tab arrows here (prev / next view), like Y toggles — they
	# steer the screen rather than emit a timeline card.
	if b == JOY_BUTTON_LEFT_SHOULDER or b == JOY_BUTTON_RIGHT_SHOULDER:
		if event.pressed:
			_select_view(-1 if b == JOY_BUTTON_LEFT_SHOULDER else 1)
			_gamepad_button_frame = Engine.get_process_frames()
		return

	var info = _button_def(b)
	if info.is_empty():
		return
	_gamepad_button_frame = Engine.get_process_frames()

	if event.pressed:
		var e = _push({
			kind = KIND_BUTTON,
			color = info.color,
			text = info.label,
			caption = info.action,
			live = true,
		})
		_button_holds[b] = e
	else:
		var e = _button_holds.get(b)
		if e:
			e.live = false
			e.duration_ms = Time.get_ticks_msec() - e.start_ms
		_button_holds.erase(b)

func _on_joypad_motion(event: InputEventJoypadMotion):
	var d := event.device
	match event.axis:
		JOY_AXIS_TRIGGER_LEFT:
			_left_trigger_by_device[d] = event.axis_value
			_left_trigger = _strongest_scalar_in(_left_trigger_by_device)
			_update_trigger_card(true, _left_trigger)
			return
		JOY_AXIS_TRIGGER_RIGHT:
			_right_trigger_by_device[d] = event.axis_value
			_right_trigger = _strongest_scalar_in(_right_trigger_by_device)
			_update_trigger_card(false, _right_trigger)
			return
		JOY_AXIS_LEFT_X:
			_set_stick_axis(_left_stick_by_device, d, event.axis_value, true)
		JOY_AXIS_LEFT_Y:
			_set_stick_axis(_left_stick_by_device, d, event.axis_value, false)
		JOY_AXIS_RIGHT_X:
			_set_stick_axis(_right_stick_by_device, d, event.axis_value, true)
		JOY_AXIS_RIGHT_Y:
			_set_stick_axis(_right_stick_by_device, d, event.axis_value, false)
		_:
			return
	_left_stick = _strongest_in(_left_stick_by_device)
	_right_stick = _strongest_in(_right_stick_by_device)
	# Follow whichever stick is pushed harder, exactly like Controls, so the dominant
	# stick drives the source-tag (and the benchmark) just like the left one.
	_stick = _left_stick if _left_stick.length() >= _right_stick.length() else _right_stick
	# Only claim the frame as "stick-sourced" when actually deflected — resting drift
	# fires every frame and would mis-tag D-pad holds as STICK.
	if _stick.length() >= STICK_RELEASE:
		_stick_motion_frame = Engine.get_process_frames()
	# Each gauge latches independently so both can be displayed side by side.
	_left_latched_dir = _latch_dir(_left_stick, _left_latched_dir)
	_right_latched_dir = _latch_dir(_right_stick, _right_latched_dir)
	_update_stick_latch()

func _set_stick_axis(by_device: Dictionary, device: int, value: float, is_x: bool) -> void:
	var v: Vector2 = by_device.get(device, Vector2.ZERO)
	if is_x:
		v.x = value
	else:
		v.y = value
	by_device[device] = v

func _strongest_in(by_device: Dictionary) -> Vector2:
	var best := Vector2.ZERO
	for v in by_device.values():
		if v.length() > best.length():
			best = v
	return best

func _strongest_scalar_in(by_device: Dictionary) -> float:
	var best := 0.0
	for v in by_device.values():
		if float(v) > best:
			best = float(v)
	return best

# Raw L2/R2 timeline card — edge-detected exactly like Controls' own trigger
# handling (STICK_ENGAGE to open, STICK_RELEASE to close), so the card's lifetime
# matches what the game itself reacts to. Its "parameter" is the PEAK depth reached
# during the hold, kept live-updated in the caption while held.
func _update_trigger_card(is_left: bool, value: float) -> void:
	var down: bool = _left_trigger_down if is_left else _right_trigger_down
	if value >= STICK_ENGAGE and not down:
		_start_trigger_card(is_left, value)
	elif down:
		_bump_trigger_peak(is_left, value)
		if value < STICK_RELEASE:
			_end_trigger_card(is_left)

func _start_trigger_card(is_left: bool, value: float) -> void:
	_trigger_frame = Engine.get_process_frames()
	var label := 'L2' if is_left else 'R2'
	var accent := _left_stick_color if is_left else _right_stick_color
	var e = _push({
		kind = KIND_TRIGGER,
		color = accent,
		text = label,
		caption = 'peak %.2f' % value,
		live = true,
	})
	if is_left:
		_left_trigger_down = true
		_left_trigger_peak = value
		_left_trigger_entry = e
	else:
		_right_trigger_down = true
		_right_trigger_peak = value
		_right_trigger_entry = e

func _bump_trigger_peak(is_left: bool, value: float) -> void:
	var entry: Dictionary = _left_trigger_entry if is_left else _right_trigger_entry
	var peak: float = maxf(_left_trigger_peak if is_left else _right_trigger_peak, value)
	if is_left:
		_left_trigger_peak = peak
	else:
		_right_trigger_peak = peak
	if entry:
		entry.caption = 'peak %.2f' % peak

func _end_trigger_card(is_left: bool) -> void:
	var entry: Dictionary = _left_trigger_entry if is_left else _right_trigger_entry
	if entry:
		entry.live = false
		entry.duration_ms = Time.get_ticks_msec() - entry.start_ms
	if is_left:
		_left_trigger_down = false
		_left_trigger_entry = {}
	else:
		_right_trigger_down = false
		_right_trigger_entry = {}

# ------------------------------------------------------------------------------

# Captions carry the Controls action id, not a game meaning: the vocabulary is the
# same on every pad brand, which is precisely what a training room should show.
func _button_def(b: int) -> Dictionary:
	var th: _ThemeData = theme_data
	match b:
		JOY_BUTTON_A: return {label = 'A', action = 'button_a', color = th.accent_action}
		JOY_BUTTON_B: return {label = 'B', action = 'button_b', color = th.accent_neutral}
		JOY_BUTTON_X: return {label = 'X', action = 'button_x', color = th.accent_action}
		JOY_BUTTON_Y: return {label = 'Y', action = 'button_y', color = th.accent_alert}
		JOY_BUTTON_LEFT_SHOULDER: return {label = 'L1', action = 'shoulder_left', color = th.accent_neutral}
		JOY_BUTTON_RIGHT_SHOULDER: return {label = 'R1', action = 'shoulder_right', color = th.accent_neutral}
		JOY_BUTTON_START: return {label = 'START', action = 'start', color = th.accent_neutral}
		JOY_BUTTON_BACK: return {label = 'SELECT', action = 'select', color = th.accent_neutral}
		JOY_BUTTON_LEFT_STICK: return {label = 'L3', action = 'stick_left', color = th.accent_neutral}
		JOY_BUTTON_RIGHT_STICK: return {label = 'R3', action = 'stick_right', color = th.accent_neutral}
	return {}

func _latch_dir(v: Vector2, prev: int) -> int:
	# Mirror Controls' hysteresis: below RELEASE → neutral, above ENGAGE →
	# (re)latch dominant 4-way, in-between → hold the previous latch.
	var mag = v.length()
	if mag < STICK_RELEASE:
		return -1
	elif mag >= STICK_ENGAGE:
		return _dominant_dir(v)
	return prev

func _update_stick_latch():
	# Dominant-stick latch with engage/dwell timing (drives the benchmark models).
	var prev = _stick_latched_dir
	_stick_latched_dir = _latch_dir(_stick, _stick_latched_dir)
	if prev == -1 and _stick_latched_dir != -1:
		_stick_engage_ms = Time.get_ticks_msec()
	elif prev != -1 and _stick_latched_dir == -1:
		_stick_last_dwell_ms = Time.get_ticks_msec() - _stick_engage_ms

func _dominant_dir(v: Vector2) -> int:
	if absf(v.x) > absf(v.y):
		return _DIR_RIGHT if v.x > 0.0 else _DIR_LEFT
	return _DIR_BOTTOM if v.y > 0.0 else _DIR_TOP

# ------------------------------------------------------------------------------
# Direction holds (keyboard arrows/WASD, D-pad, stick) — tag the real source.
# ------------------------------------------------------------------------------

func _on_hold_started(direction: int):
	_current_dir = direction
	var e = _push({
		kind = KIND_HOLD,
		dir = direction,
		color = theme_data.accent_keyboard,
		caption = 'KB',
		source = 'KB',
		live = true,
		release_ms = -1,
		end_ms = -1,
	})
	_hold_entry = e
	_bench.hold_started('KB', false, _stick.length(), Time.get_ticks_msec())
	_tag_hold_source.call_deferred(e, Engine.get_process_frames())

func _tag_hold_source(e: Dictionary, frame: int):
	# A timer-driven stick rush emits its hold on a frame with no motion event, so the
	# frame check misses it → also treat a currently-deflected stick as STICK.
	if _stick_motion_frame == frame or _stick.length() >= STICK_RELEASE:
		# `source` stays 'STICK' (the benchmark keys off it); only the visible caption
		# and colour split by the harder-pushed stick, mirroring the dominant `_stick`.
		var is_right := _right_stick.length() > _left_stick.length()
		e.source = 'STICK'
		e.caption = 'R-STICK' if is_right else 'L-STICK'
		e.color = _right_stick_color if is_right else _left_stick_color
	elif _dpad_frame == frame:
		e.source = 'D-PAD'
		e.caption = 'D-PAD'
		e.color = theme_data.accent_dpad
	_current_source = e.source
	_bench.cur_source = e.source
	_bench.cur_gamepad = e.source != 'KB'

func _on_hold_ended(is_gamepad: bool):
	_bench.cur_gamepad = is_gamepad
	_bench.hold_ended(Time.get_ticks_msec())
	if _hold_entry:
		var now = Time.get_ticks_msec()
		var held = now - _hold_entry.start_ms
		_hold_entry.live = false
		_hold_entry.duration_ms = held
		_hold_entry.release_ms = now
		# A short tap is a single cell (no rush) → no grace; a sustained hold rushes,
		# so the interaction really ends after the release-grace window.
		var grace = 0
		if held >= _bench.cancel_ms:
			grace = _bench.gamepad_grace_ms if is_gamepad else _bench.release_grace_ms
		_hold_entry.end_ms = now + grace
	_hold_entry = {}
	_current_dir = -1

# ------------------------------------------------------------------------------
# Discrete events — gated so a gamepad button shows only as its raw card.
# ------------------------------------------------------------------------------

# On a gamepad, the primary button can emit a tap and an indexed action on the same
# frame; resolving the tap deferred and dropping it when that frame carried a switch
# or a gamepad button keeps a single, correct card.
func _on_tapped():
	_resolve_tap.call_deferred(Engine.get_process_frames())

func _resolve_tap(frame: int):
	if _switch_frame_idx == frame or _gamepad_button_frame == frame:
		return
	_push({kind = KIND_TAP, color = theme_data.accent_dpad, text = 'TAP'})

func _on_switched():
	var f = Engine.get_process_frames()
	_switch_frame_idx = f
	_kb_card.call_deferred(f, {kind = KIND_SWITCH, color = theme_data.accent_action, text = 'SHIFT'})

func _on_reset():
	_resolve_reset.call_deferred(Engine.get_process_frames())

func _resolve_reset(frame: int):
	# Y (gamepad) toggles the view and sets _gamepad_button_frame, so its reset is
	# swallowed here; only the keyboard R resets the metrics.
	if _gamepad_button_frame == frame:
		return
	if _view == 'benchmark':
		_bench.reset_metrics()
	_push({kind = KIND_RESET, color = theme_data.accent_alert, text = 'R'})

func _on_back():
	_kb_card.call_deferred(Engine.get_process_frames(), {kind = KIND_BACK, color = theme_data.accent_neutral, text = 'ESC'})

func _kb_card(frame: int, dict: Dictionary):
	if _gamepad_button_frame == frame:
		return
	_push(dict)

func _on_retrigger(index: int):
	_push({kind = KIND_RETRIGGER, color = theme_data.accent_index, text = str(index)})

func _on_focus_started():
	_focus_active = true
	_focus_entry = {}
	_maybe_focus_card.call_deferred(Engine.get_process_frames())

func _maybe_focus_card(frame: int):
	# The raw trigger already got its own KIND_TRIGGER card (real depth as parameter)
	# on this same frame — swallow the FOCUS duplicate, same reasoning as the
	# gamepad-button swallow above. A keyboard focus key has no raw trigger frame, so
	# it always keeps its FOCUS card.
	if _gamepad_button_frame == frame or _trigger_frame == frame:
		return
	_focus_entry = _push({
		kind = KIND_FOCUS,
		color = theme_data.accent_focus,
		text = 'FOCUS',
		caption = 'trigger_left',
		live = true,
	})

func _on_focus_moved(direction: int):
	_flash_dir = direction
	_flash_t = 1.0
	_push({kind = KIND_FOCUS_MOVE, dir = direction, color = theme_data.accent_focus})

# Raw release: the base has no notion of a focus being accepted or dropped, so the
# card simply closes. A game's semantic layer uses the two below instead.
func _on_focus_ended():
	_finish_focus('END', theme_data.accent_neutral)

func _on_focus_confirmed():
	_finish_focus('OK', theme_data.accent_dpad)

func _on_focus_cancelled():
	_finish_focus('X', theme_data.accent_neutral)

func _finish_focus(suffix: String, tint: Color):
	_focus_active = false
	if _focus_entry:
		_focus_entry.live = false
		_focus_entry.duration_ms = Time.get_ticks_msec() - _focus_entry.start_ms
		_focus_entry.tag = suffix
		_focus_entry.tag_color = tint
	_focus_entry = {}

# ------------------------------------------------------------------------------

func clear_history() -> void:
	_entries.clear()
	_focus_entry = {}
	_last_event_ms = 0
	queue_redraw()

# ------------------------------------------------------------------------------

func _push(e: Dictionary) -> Dictionary:
	var now = Time.get_ticks_msec()
	e.start_ms = now
	e.appear_t = 0.0
	e.gap_ms = now - _last_event_ms if _last_event_ms > 0 else 0
	if not e.has('duration_ms'):
		e.duration_ms = 0
	if not e.has('live'):
		e.live = false
	_last_event_ms = now
	_entries.append(e)
	while _entries.size() > _max_cards:
		_entries.pop_front()
	queue_redraw()
	return e

# ------------------------------------------------------------------------------

func _process(delta):
	var now = Time.get_ticks_msec()
	for e in _entries:
		if e.live:
			e.duration_ms = now - e.start_ms
		if e.appear_t < 1.0:
			e.appear_t = minf(1.0, e.appear_t + delta / 0.16)
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - delta / 0.25)
	for trail in [_left_trail, _right_trail, _stick_trail]:
		while trail.size() > TRAIL_LEN:
			trail.pop_front()
	_left_trail.append(_left_stick)
	_right_trail.append(_right_stick)
	_stick_trail.append(_stick)
	_bench.tick(now)
	queue_redraw()

# ------------------------------------------------------------------------------
# Drawing
# ------------------------------------------------------------------------------

func _draw():
	_ensure_theme()
	if footer_only:
		_draw_timeline(self)
		return
	_draw_view_tabs(self)
	if _view == 'benchmark':
		_draw_benchmark(self)
		_draw_stick_gauge(self)
		_draw_timeline(self)
		return
	_draw_legend(self)
	_draw_dual_sticks(self)
	_draw_live_cross(self)
	_draw_timeline(self)

func _draw_timeline(c: CanvasItem):
	var line_color = Color(theme_data.accent_keyboard, 0.12)
	c.draw_line(Vector2(_track_left, _baseline_y + 1), Vector2(_vp.x - _track_left, _baseline_y + 1), line_color, 1.0)
	var x = _track_left
	for e in _entries:
		_draw_card(c, e, x)
		x += _card_w + _gap

func _draw_card(c: CanvasItem, e: Dictionary, x: float):
	var appear = e.appear_t
	var alpha = appear
	var top = _baseline_y - _card_h + (1.0 - appear) * 22.0
	var rect = Rect2(x, top, _card_w, _card_h)
	var color: Color = e.color

	c.draw_rect(rect, Color(color, 0.06 * alpha), true)
	c.draw_rect(rect, Color(color, 0.10 * alpha), false, 6.0)
	c.draw_rect(rect, Color(color, 0.55 * alpha), false, 1.5)
	if e.live:
		c.draw_rect(rect.grow(3.0), Color(color, 0.18 * alpha), false, 1.0)

	var glyph_center = Vector2(x + _card_w * 0.5, top + _card_h * 0.26)
	var glyph_s = _card_h * 0.17
	match e.kind:
		KIND_HOLD, KIND_FOCUS_MOVE:
			_draw_arrow(c, glyph_center, glyph_s, e.dir, Color(color, alpha))
		KIND_TAP:
			Dot.draw(c, glyph_center, glyph_s * 0.62, Color(color, alpha))
		KIND_FOCUS:
			c.draw_arc(glyph_center, glyph_s * 0.7, 0, TAU, 28, Color(color, alpha), 2.0)
			Dot.draw(c, glyph_center, glyph_s * 0.18, Color(color, alpha))
		_:
			_draw_centered_text(c, e.get('text', '?'), glyph_center, theme_data.size_glyph, Color(color, alpha), theme_data.ui_font())

	if e.has('caption'):
		_draw_centered_text(c, e.caption, Vector2(x + _card_w * 0.5, top + _card_h * 0.45), theme_data.size_caption, Color(color, 0.7 * alpha), theme_data.ui_font())
	if e.has('tag'):
		_draw_centered_text(c, e.tag, Vector2(x + _card_w * 0.5, top + _card_h * 0.47), theme_data.size_caption, Color(e.tag_color, alpha), theme_data.ui_font())

	var timing_center = Vector2(x + _card_w * 0.5, top + _card_h * 0.86)
	if e.kind == KIND_HOLD:
		# One card per press → press/release/end timestamps, relative to the press (@0).
		var fs = theme_data.size_glyph
		var cx = x + _card_w * 0.5
		var rel = e.release_ms - e.start_ms if e.get('release_ms', -1) >= 0 else -1
		var end = e.end_ms - e.start_ms if e.get('end_ms', -1) >= 0 else -1
		_draw_centered_text(c, 'P @0', Vector2(cx, top + _card_h * 0.62), fs, Color(color, 0.9 * alpha), theme_data.body_font())
		var rel_txt = 'R @%d' % rel if rel >= 0 else 'R ...'
		_draw_centered_text(c, rel_txt, Vector2(cx, top + _card_h * 0.77), fs, Color(color, 0.9 * alpha), theme_data.body_font())
		var end_txt = 'E @%d' % end if end >= 0 else 'E ...'
		_draw_centered_text(c, end_txt, Vector2(cx, top + _card_h * 0.92), fs, Color(color, 0.7 * alpha), theme_data.body_font())
	elif e.kind == KIND_FOCUS or e.kind == KIND_BUTTON or e.kind == KIND_TRIGGER:
		_draw_centered_text(c, '%d ms' % e.duration_ms, timing_center, theme_data.size_caption, Color(color, 0.9 * alpha), theme_data.body_font())
	else:
		_draw_centered_text(c, '+%d ms' % e.gap_ms, timing_center, theme_data.size_timing, Color(theme_data.text_secondary, alpha), theme_data.body_font())

# ------------------------------------------------------------------------------

func _draw_live_cross(c: CanvasItem):
	var dir = _current_dir
	if dir == -1 and _flash_t > 0.0:
		dir = _flash_dir

	var reach = _card_h * 0.58
	var arrow_s = _card_h * 0.15
	var base = Color(theme_data.accent_keyboard, 0.14)
	var lit = theme_data.accent_keyboard if not _focus_active else theme_data.accent_focus

	var offsets = {
		_DIR_TOP: Vector2(0, -reach),
		_DIR_RIGHT: Vector2(reach, 0),
		_DIR_BOTTOM: Vector2(0, reach),
		_DIR_LEFT: Vector2(-reach, 0),
	}
	for d in offsets:
		var pos = _cross_center + offsets[d]
		var is_on = d == dir
		var col = Color(lit, 1.0) if is_on else base
		_draw_arrow(c, pos, arrow_s, d, col)
		if is_on:
			_draw_arrow(c, pos, arrow_s, d, Color(lit, 0.18))

	_draw_centered_text(c, 'DIRECTION', _cross_center + Vector2(0, -reach - _card_h * 0.34), int(_card_h * 0.12), Color(theme_data.text_secondary, 0.7), theme_data.ui_font())

	var status := 'IDLE'
	var status_color: Color = theme_data.text_secondary
	if _focus_active and _focus_entry:
		status = 'FOCUS · %d ms' % _focus_entry.duration_ms
		status_color = theme_data.accent_focus
	elif _hold_entry:
		status = '%s · %s · %d ms' % [DIR_NAMES[_hold_entry.dir], _current_source, _hold_entry.duration_ms]
		status_color = theme_data.accent_keyboard
	_draw_centered_text(c, status, _cross_center + Vector2(0, reach + _card_h * 0.40), int(_card_h * 0.17), status_color, theme_data.ui_font())

# ------------------------------------------------------------------------------
# Stick telemetry gauges — shared rings/dynamics, two layouts:
#   inputs view → LEFT + RIGHT gauges (compact metrics) flanking the cross;
#   benchmark view → single dominant-stick gauge with the full side metrics.
# ------------------------------------------------------------------------------

func _draw_dual_sticks(c: CanvasItem):
	# L2 fills RIGHT→LEFT (mirrored) so both trigger bars grow outward from the
	# center, away from their stick — matching the physical L2/R2 layout instead
	# of both bars filling toward the same visual direction.
	_draw_gauge(c, _left_stick_center, 'LEFT STICK', _left_stick, _left_latched_dir, _left_trail, _left_stick_color, 'L2', _left_trigger, true)
	_draw_gauge(c, _right_stick_center, 'RIGHT STICK', _right_stick, _right_latched_dir, _right_trail, _right_stick_color, 'R2', _right_trigger)

# `trigger_label`/`trigger_value` render the analog L2/R2 depth as a filled bar at
# the TOP of this same stick panel (real controller layout: the trigger sits above
# the stick, not a separate floating gauge) — L2/R2 are analog like the stick, so a
# plain on/off card (as the face buttons get) would hide the pressure depth one pad
# might report differently from another.
func _draw_gauge(c: CanvasItem, center: Vector2, label: String, stick: Vector2, latched: int, trail: Array, accent: Color = Color.WHITE, trigger_label: String = '', trigger_value: float = 0.0, trigger_reverse: bool = false):
	var r = _stick_radius
	var pad = _card_h * 0.25
	var trigger_h = _card_h * 0.34 if trigger_label != '' else 0.0
	var panel = Rect2(
		center.x - r - pad,
		center.y - r - _card_h * 0.42 - trigger_h,
		2.0 * (r + pad),
		2.0 * r + _card_h * 1.42 + trigger_h,
	)
	c.draw_rect(panel, Color(theme_data.panel_background, 0.55), true)
	c.draw_rect(panel, Color(accent, 0.16), false, 1.0)
	if trigger_label != '':
		var bar_center = Vector2(center.x, panel.position.y + trigger_h * 0.58)
		_draw_trigger_bar(c, bar_center, panel.size.x - _card_h * 0.30, trigger_h * 0.4, trigger_label, trigger_value, accent, trigger_reverse)
	_draw_centered_text(c, label, center + Vector2(0, -r - _card_h * 0.24), int(_card_h * 0.13), Color(accent, 0.9), theme_data.ui_font())
	_draw_gauge_rings(c, center, r, accent)
	_draw_gauge_dynamics(c, center, r, stick, latched, trail, accent)
	_draw_gauge_metrics(c, center, r, stick, latched)

# Linear analog gauge for L2/R2 depth (0.0-1.0), graduated with the SAME
# engage/release ticks as the stick rings so the two read as one consistent
# language: a dim track, engage / release reference lines, and a fill that
# brightens through the same zone colours as the stick's live dot.
# `reverse` anchors the fill (and the engage/release ticks) to the RIGHT edge
# instead of the left, so L2 can grow right→left while R2 keeps left→right.
func _draw_trigger_bar(c: CanvasItem, center: Vector2, w: float, h: float, label: String, value: float, accent: Color, reverse: bool = false):
	var rect = Rect2(center.x - w * 0.5, center.y - h * 0.5, w, h)
	var zone_color = theme_data.text_secondary
	if value >= STICK_ENGAGE:
		zone_color = theme_data.accent_dpad
	elif value >= STICK_RELEASE:
		zone_color = theme_data.accent_focus
	c.draw_rect(rect, Color(theme_data.panel_background, 0.4), true)
	c.draw_rect(rect, Color(accent, 0.30), false, 1.0)
	var engage_frac = (1.0 - STICK_ENGAGE) if reverse else STICK_ENGAGE
	var release_frac = (1.0 - STICK_RELEASE) if reverse else STICK_RELEASE
	var engage_x = rect.position.x + w * engage_frac
	var release_x = rect.position.x + w * release_frac
	c.draw_line(Vector2(engage_x, rect.position.y), Vector2(engage_x, rect.position.y + h), Color(theme_data.accent_dpad, 0.45), 1.0)
	c.draw_line(Vector2(release_x, rect.position.y), Vector2(release_x, rect.position.y + h), Color(theme_data.text_secondary, 0.4), 1.0)
	var fill_w = w * clampf(value, 0.0, 1.0)
	if fill_w > 0.5:
		var fill_x = rect.position.x + w - fill_w if reverse else rect.position.x
		c.draw_rect(Rect2(Vector2(fill_x, rect.position.y), Vector2(fill_w, h)), Color(zone_color, 0.8), true)
	_draw_text_left(c, '%s  %.2f' % [label, value], Vector2(rect.position.x, rect.position.y - h * 0.35), int(clampf(h * 0.85, 10, 16)), Color(accent, 0.9), theme_data.ui_font())

func _draw_stick_gauge(c: CanvasItem):
	var center = _stick_center
	var r = _stick_radius
	var accent = theme_data.accent_keyboard

	var pad = _card_h * 0.28
	var right_edge = center.x + r + _card_h * 0.30 + _card_h * 1.7 + _card_h * 1.6
	var panel = Rect2(
		center.x - r - pad,
		center.y - r - _card_h * 0.5,
		(right_edge + pad) - (center.x - r - pad),
		2.0 * r + _card_h * 0.9,
	)
	c.draw_rect(panel, Color(theme_data.panel_background, 0.55), true)
	c.draw_rect(panel, Color(accent, 0.16), false, 1.0)

	_draw_centered_text(c, 'STICK', center + Vector2(0, -r - _card_h * 0.30), int(_card_h * 0.13), Color(theme_data.text_secondary, 0.9), theme_data.ui_font())
	_draw_gauge_rings(c, center, r, accent)
	_draw_gauge_dynamics(c, center, r, _stick, _stick_latched_dir, _stick_trail, accent)
	_draw_stick_metrics(c, center, r, _stick.length(), _stick_latched_dir)

func _draw_gauge_rings(c: CanvasItem, center: Vector2, r: float, accent: Color = Color.WHITE):
	# Axes + rings: outer (1.0), engage, release/deadzone.
	c.draw_line(center + Vector2(-r, 0), center + Vector2(r, 0), Color(accent, 0.10), 1.0)
	c.draw_line(center + Vector2(0, -r), center + Vector2(0, r), Color(accent, 0.10), 1.0)
	c.draw_arc(center, r, 0, TAU, 64, Color(accent, 0.30), 1.5)
	c.draw_arc(center, r * STICK_ENGAGE, 0, TAU, 56, Color(theme_data.accent_dpad, 0.45), 1.5)
	c.draw_arc(center, r * STICK_RELEASE, 0, TAU, 48, Color(theme_data.text_secondary, 0.45), 1.0)

func _draw_gauge_dynamics(c: CanvasItem, center: Vector2, r: float, stick: Vector2, latched: int, trail: Array, accent: Color = Color.WHITE):
	# Highlight the latched 4-way sector on the outer ring.
	if latched != -1:
		var ang = [-PI * 0.5, 0.0, PI * 0.5, PI][latched]
		var tip = center + Vector2(cos(ang), sin(ang)) * r
		_draw_arrow(c, tip, _card_h * 0.13, latched, Color(theme_data.accent_dpad, 0.9))

	# Jitter trail (oldest faint → newest bright) — reveals drift at rest.
	var n = trail.size()
	for i in range(n):
		var a = float(i + 1) / float(n) * 0.35
		Dot.draw(c, center + trail[i] * r, 2.0, Color(accent, a))

	# Live dot, coloured by zone (dead / hysteresis band / live).
	var mag = stick.length()
	var dot_color = theme_data.text_secondary
	if mag >= STICK_ENGAGE:
		dot_color = theme_data.accent_dpad
	elif mag >= STICK_RELEASE:
		dot_color = theme_data.accent_focus
	var dot = center + stick * r
	c.draw_line(center, dot, Color(dot_color, 0.5), 1.5)
	Dot.draw(c, dot, _card_h * 0.045, Color(dot_color, 1.0))
	Dot.draw(c, dot, _card_h * 0.075, Color(dot_color, 0.25))

func _draw_gauge_metrics(c: CanvasItem, center: Vector2, r: float, stick: Vector2, latched: int):
	# Compact two-column readout below the gauge (X/Y/MAG · ANG/ZONE/DIR).
	var mag = stick.length()
	var zone := 'DEAD'
	var zone_color: Color = theme_data.text_secondary
	if mag >= STICK_ENGAGE:
		zone = 'LIVE'
		zone_color = theme_data.accent_dpad
	elif mag >= STICK_RELEASE:
		zone = 'BAND'
		zone_color = theme_data.accent_focus

	var angle = int(round(rad_to_deg(atan2(stick.y, stick.x))))
	var dir_txt = DIR_NAMES[latched] if latched != -1 else '-'
	var fs = int(clampf(_card_h * 0.13, 12, 18))
	var lh = fs * 1.55
	var top = center.y + r + fs * 1.2
	var key_color = theme_data.text_key
	var value_color = theme_data.text_value
	var dir_color: Color = theme_data.accent_dpad if latched != -1 else key_color
	var left_rows = [['X', '%+.2f' % stick.x, value_color], ['Y', '%+.2f' % stick.y, value_color], ['MAG', '%.2f' % mag, value_color]]
	var right_rows = [['ANG', '%d°' % angle, value_color], ['ZONE', zone, zone_color], ['DIR', dir_txt, dir_color]]
	var lx = center.x - r * 0.95
	var lv = center.x - r * 0.30
	var rx = center.x + r * 0.15
	var rv = center.x + r * 0.62
	for i in range(3):
		var y = top + i * lh
		_draw_text_left(c, left_rows[i][0], Vector2(lx, y), fs, key_color, theme_data.ui_font())
		_draw_text_left(c, left_rows[i][1], Vector2(lv, y), fs, left_rows[i][2], theme_data.body_font())
		_draw_text_left(c, right_rows[i][0], Vector2(rx, y), fs, key_color, theme_data.ui_font())
		_draw_text_left(c, right_rows[i][1], Vector2(rv, y), fs, right_rows[i][2], theme_data.body_font())

func _draw_stick_metrics(c: CanvasItem, center: Vector2, r: float, mag: float, latched: int):
	var zone := 'DEAD'
	var zone_color: Color = theme_data.text_secondary
	if mag >= STICK_ENGAGE:
		zone = 'LIVE'
		zone_color = theme_data.accent_dpad
	elif mag >= STICK_RELEASE:
		zone = 'BAND'
		zone_color = theme_data.accent_focus

	var angle = int(round(rad_to_deg(atan2(_stick.y, _stick.x))))
	var dir_txt = DIR_NAMES[latched] if latched != -1 else '-'
	var fs = int(clampf(_card_h * 0.15, 14, 21))
	var px = center.x + r + _card_h * 0.30
	var vx = px + _card_h * 1.7
	var py = center.y - r + fs
	var lh = fs * 1.6
	var key_color = theme_data.text_key
	var value_color = theme_data.text_value

	var rows = [
		['X', '%+.2f' % _stick.x, value_color],
		['Y', '%+.2f' % _stick.y, value_color],
		['MAG', '%.2f' % mag, value_color],
		['ANGLE', '%d°' % angle, value_color],
		['ENGAGE', '%.2f' % STICK_ENGAGE, key_color],
		['RELEASE', '%.2f' % STICK_RELEASE, key_color],
		['ZONE', zone, zone_color],
		['LATCHED', dir_txt, theme_data.accent_dpad if latched != -1 else key_color],
	]
	for i in range(rows.size()):
		var y = py + i * lh
		_draw_text_left(c, rows[i][0], Vector2(px, y), fs, key_color, theme_data.ui_font())
		_draw_text_left(c, rows[i][1], Vector2(vx, y), fs, rows[i][2], theme_data.body_font())

# ------------------------------------------------------------------------------

# The two legend lines, in the fox Controls vocabulary. Override to print the
# game's own meaning for each key and button.
func _legend_lines() -> Array:
	return [
		'ARROWS / WASD hold    SPACE tap    CTRL trigger_left    SHIFT button_x    R button_y    1-9 number    ESC button_b',
		'GAMEPAD :  D-PAD / STICK direction    L2 / R2 analog depth    A·B·X·Y face buttons    L1 · R1 tabs    START · SELECT',
	]

func _draw_legend(c: CanvasItem):
	var lines = _legend_lines()
	var size = int(clampf(_vp.y * 0.017, 11, 17))
	var y_ratios = [0.150, 0.178]
	var alphas = [0.7, 0.6]
	for i in range(min(lines.size(), y_ratios.size())):
		_draw_centered_text(c, lines[i], Vector2(_vp.x * 0.5, _vp.y * y_ratios[i]), size, Color(theme_data.text_secondary, alphas[i]), theme_data.body_font())

# Tab-arrow hints. The base prints the hardware label of the shoulder buttons when
# a pad is the active device, the keyboard keys otherwise; Controls owns both facts.
func _prev_tab_glyph() -> String:
	if Controls.last_input_was_gamepad:
		return 'L1' if Controls.is_playstation_pad() else 'LB'
	return 'PG UP'

func _next_tab_glyph() -> String:
	if Controls.last_input_was_gamepad:
		return 'R1' if Controls.is_playstation_pad() else 'RB'
	return 'PG DN'

func _draw_view_tabs(c: CanvasItem):
	# Tabs flanked by prev/next arrows: ‹ LB  INPUTS  BENCHMARK  RB ›  on a pad,
	# ‹ PG UP  INPUTS  BENCHMARK  PG DN ›  on a keyboard. Active tab lit.
	var font = theme_data.ui_font()
	var fs = int(clampf(_vp.y * 0.016, 11, 16))
	var on = theme_data.accent_keyboard
	var off = Color(theme_data.text_secondary, 0.6)
	var hint = Color(theme_data.text_secondary, 0.5)
	var gap = fs * 1.4
	var inputs_active = _view == 'inputs'

	var segs = [
		['‹ %s' % _prev_tab_glyph(), hint],
		['INPUTS', on if inputs_active else off],
		['BENCHMARK', off if inputs_active else on],
		['%s ›' % _next_tab_glyph(), hint],
	]

	var widths = []
	var total = gap * (segs.size() - 1)
	for s in segs:
		var w = font.get_string_size(s[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append(w)
		total += w

	var x = _vp.x * 0.5 - total * 0.5
	var y = _vp.y * 0.115
	for i in range(segs.size()):
		c.draw_string(font, Vector2(x, y), segs[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, segs[i][1])
		x += widths[i] + gap

# ------------------------------------------------------------------------------
# Benchmark view — simulated cadence per source × mode
# ------------------------------------------------------------------------------

func _draw_benchmark(c: CanvasItem):
	var now = Time.get_ticks_msec()
	var bx0 = _vp.x * 0.06
	var bx1 = _vp.x * 0.43
	var width = bx1 - bx0
	var track_y = _vp.y * 0.285
	var fs = int(clampf(_vp.y * 0.019, 13, 20))
	var key_color = theme_data.text_key
	var muted = Color(theme_data.text_secondary, 0.85)

	var panel = Rect2(_vp.x * 0.035, _vp.y * 0.185, _vp.x * 0.43, _vp.y * 0.53)
	c.draw_rect(panel, Color(theme_data.panel_background, 0.6), true)
	c.draw_rect(panel, Color(theme_data.accent_keyboard, 0.16), false, 1.0)

	# Track of cells + simulated pawn.
	c.draw_line(Vector2(bx0, track_y), Vector2(bx1, track_y), Color(theme_data.accent_keyboard, 0.18), 1.0)
	var spacing = width / float(_Benchmark.TRACK_CELLS - 1)
	for i in range(_Benchmark.TRACK_CELLS):
		var x = bx0 + i * spacing
		c.draw_line(Vector2(x, track_y - 5), Vector2(x, track_y + 5), Color(theme_data.accent_keyboard, 0.14), 1.0)
	var pawn_col = _left_stick_color if _bench.cur_source == 'STICK' else (theme_data.accent_dpad if _bench.cur_source == 'D-PAD' else theme_data.accent_keyboard)
	var px = bx0 + _bench.pos * spacing
	Dot.draw(c, Vector2(px, track_y), 8.0, Color(pawn_col, 0.9))
	Dot.draw(c, Vector2(px, track_y), 14.0, Color(pawn_col, 0.22))

	# Live push readout.
	var mode = _bench.current_mode()
	var dwell = _bench.dwell_ms(now)
	var dwell_col = theme_data.accent_focus if (mode == 'RUSH') else theme_data.accent_dpad
	var live = 'PUSH  %s · %s · %d cells · dwell %d ms (cancel @%d)' % [_bench.cur_source, mode, _bench.push_cells if _bench.continuous else 0, dwell, _bench.cancel_ms]
	_draw_text_left(c, live, Vector2(bx0, track_y - _vp.y * 0.06), fs, Color(dwell_col, 0.95) if _bench.continuous else muted, theme_data.ui_font())

	# Stats table.
	var ty = track_y + _vp.y * 0.06
	var lh = fs * 1.7
	var c_src = bx0
	var c_tap = bx0 + width * 0.42
	var c_rush = bx0 + width * 0.66
	_draw_text_left(c, 'SOURCE', Vector2(c_src, ty), fs, muted, theme_data.ui_font())
	_draw_text_left(c, 'TAP  cells/push', Vector2(c_tap, ty), fs, muted, theme_data.ui_font())
	_draw_text_left(c, 'RUSH  cells/s · ms', Vector2(c_rush, ty), fs, muted, theme_data.ui_font())

	var sources = ['KB', 'D-PAD', 'STICK']
	for i in range(sources.size()):
		var s = sources[i]
		var y = ty + (i + 1) * lh
		var accent = _left_stick_color if s == 'STICK' else theme_data.text_value
		_draw_text_left(c, s, Vector2(c_src, y), fs, accent, theme_data.ui_font())
		var cpp = _bench.cells_per_push(s, 'NORMAL')
		var cpp_rush = _bench.cells_per_push(s, 'RUSH')
		_draw_text_left(c, ('%.1f' % cpp) if cpp > 0 else '-', Vector2(c_tap, y), fs, key_color, theme_data.body_font())
		var cps = _bench.cells_per_s(s, 'RUSH')
		var mpc = _bench.ms_per_cell(s, 'RUSH')
		var rush_txt = '-'
		if cps > 0:
			rush_txt = '%.1f · %d ms   (%.1f c/push)' % [cps, int(round(mpc)), cpp_rush]
		_draw_text_left(c, rush_txt, Vector2(c_rush, y), fs, key_color, theme_data.body_font())

	# Stick-model comparison: cells produced for the live stick dwell under the 3
	# candidate models — turns the "which fix" decision into side-by-side numbers.
	var stick_dwell = _stick_last_dwell_ms
	if _stick_latched_dir != -1:
		stick_dwell = now - _stick_engage_ms
	var cy = ty + 4.0 * lh
	_draw_text_left(c, 'STICK MODEL   @ push dwell %d ms' % stick_dwell, Vector2(c_src, cy), fs, theme_data.accent_focus, theme_data.ui_font())
	var models = [
		['CURRENT  rush', 'current', _left_stick_color],
		['OPTION 2  repeat', 'repeat', theme_data.accent_dpad],
		['OPTION 1  arm', 'arm', theme_data.accent_keyboard],
	]
	for i in range(models.size()):
		var y = cy + (i + 1) * lh
		var key = models[i][1]
		var cells = _bench.model_cells(key, stick_dwell)
		var cps = _bench.model_cps(key)
		_draw_text_left(c, models[i][0], Vector2(c_src, y), fs, models[i][2], theme_data.ui_font())
		_draw_text_left(c, '%d cells' % cells, Vector2(c_tap, y), fs, key_color, theme_data.body_font())
		_draw_text_left(c, '~%.1f c/s' % cps, Vector2(c_rush, y), fs, key_color, theme_data.body_font())

	var params = 'OPT2 delay %d/int %d · OPT1 arm %d · cancel %d (ms)' % [_bench.repeat_initial_ms, _bench.repeat_interval_ms, _bench.arm_ms, _bench.cancel_ms]
	_draw_text_left(c, params, Vector2(c_src, cy + 4.2 * lh), int(fs * 0.82), Color(theme_data.text_secondary, 0.6), theme_data.body_font())

# ------------------------------------------------------------------------------
# Primitives
# ------------------------------------------------------------------------------

func _draw_arrow(c: CanvasItem, center: Vector2, s: float, dir: int, color: Color):
	var angle = [0.0, PI * 0.5, PI, PI * 1.5][dir]
	var pts = [
		Vector2(0, -s),
		Vector2(s * 0.8, s * 0.55),
		Vector2(0, s * 0.18),
		Vector2(-s * 0.8, s * 0.55),
	]
	var poly = PackedVector2Array()
	for p in pts:
		poly.append(center + p.rotated(angle))
	c.draw_colored_polygon(poly, color)

func _draw_centered_text(c: CanvasItem, text: String, center: Vector2, font_size: int, color: Color, font: Font):
	var w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	c.draw_string(font, Vector2(center.x - w * 0.5, center.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_text_left(c: CanvasItem, text: String, pos: Vector2, font_size: int, color: Color, font: Font):
	c.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
