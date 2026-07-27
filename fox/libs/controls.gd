extends Node

# ==============================================================================
# Controls — generic fox input layer (autoload).
#
# Normalises keyboard / D-pad / analog-stick / face-buttons / triggers into RAW,
# device-agnostic events. It carries ZERO game semantics: no rush, no focus, no
# reset — only "a direction went down", "the stick latched LEFT", "the confirm
# button was pressed". A game's own interpreter (e.g. EventListener) subscribes
# to these signals and derives gameplay meaning. This file must never reference a
# project's classes (DesignTokens, LevelState, anything under src/): it is shared
# by every fox game and each game keeps its own mapping + UI on top.
#
# Thresholds (STICK_*) live here because they describe the DEVICE (deadzone /
# hysteresis), not the game. The rush / tap distinction is a game concept owned by
# the interpreter — the stick latch is emitted here as a plain direction change.
# ==============================================================================

# ── Stick tuning — NEUTRAL DEFAULTS, overridable PER GAME ──────────────────────
# These describe the device feel, but the right value is GAME-specific: a fast
# arcade rusher and a slow puzzle game want different turn tolerances. So they are
# public `var`s (not consts): fox ships sane defaults and each game pushes its own
# at boot (e.g. Faraday's `InputTuning.apply()`), without forking fox. Keyboard /
# D-pad are digital and never reach the stick path, so these never affect them.
#
# Stick hysteresis: a firm push past ENGAGE latches the dominant 4-way direction;
# it only re-arms once the stick falls back below RELEASE. The gap between the two
# is the neutral band that keeps drift from latching on its own. Defaults are
# community-aligned (Godot deadzone / XInput anti-drift).
var STICK_ENGAGE: float = 0.5
var STICK_RELEASE: float = 0.25

# Keyboard-parity tuning. A digital key turns instantly; the analog stick must
# sweep an arc and cross thresholds, which adds latency a key never has. Two
# levers narrow that gap WITHOUT weakening the anti-drift ENGAGE gate:
#   • STICK_TURN — once already engaged, re-aim the dominant cardinal as soon as
#     the stick is still clearly deflected, instead of waiting for it to climb
#     back past ENGAGE. The [RELEASE, ENGAGE] freeze was pure turn latency.
#   • STICK_NEUTRAL_DEBOUNCE_MS — a flick THROUGH the centre dips to neutral for
#     a frame or two; hold the release briefly so a cardinal re-engaging within
#     the window reads as a DIRECT turn (one hold_started, no release/re-press),
#     exactly like a held-key direction change. This is the stick "buffer".
var STICK_TURN: float = 0.35
var STICK_NEUTRAL_DEBOUNCE_MS: int = 40

# Speed-adaptive turn angle (game-driven via `stick_speed_factor`). The deflection a
# turn must reach AWAY from the base axis before it commits: the classic 45° quadrant
# split at rest, shrinking toward STICK_TURN_ANGLE_FAST at top speed so a fast,
# imprecise diagonal flick still registers the turn — the stick keeps up with a rush
# instead of demanding a full throw. Keyboard is digital and never reaches this path,
# so it is untouched; other fox games leave the factor at 0 → exact 45° behaviour.
var STICK_TURN_ANGLE_SLOW: float = 45.0
var STICK_TURN_ANGLE_FAST: float = 28.0

# A direction must be held this long before it becomes the new BASE axis. Brief
# perpendicular flicks (chicanes) change the EMITTED direction but NOT the base, so
# the main travel axis is not abandoned on the first tap — the base follows the
# longest-held recent direction, which is what a chicane should pivot around.
var BASE_COMMIT_MS: int = 220

# Local 4-way ids (no dependency on a project's LevelState). Same convention as
# the flat grid: TOP=0, RIGHT=1, BOTTOM=2, LEFT=3.
const DIR_TOP: int = 0
const DIR_RIGHT: int = 1
const DIR_BOTTOM: int = 2
const DIR_LEFT: int = 3

# Steam Input injects a synthetic keyboard key alongside the real gamepad button
# (A → SPACE, B → ESCAPE, D-pad → arrows). Muting the keyboard whenever ANY pad is
# CONNECTED killed the desktop keyboard sitting next to an idle controller. Instead
# we timestamp each processed gamepad button and drop only a keyboard copy that folds
# onto the SAME action/direction within this window — the mirror arrives in the same
# frame or just after the JOY_BUTTON_* event, so a real desktop keypress (with no
# recent gamepad event) is never dropped.
const GAMEPAD_KEY_MIRROR_MS: int = 50

# ------------------------------------------------------------------------------
# Raw signals — the only public surface.
# ------------------------------------------------------------------------------

# Digital directions (arrows / WASD / D-pad). `from_gamepad` lets the interpreter
# tag the source without re-reading the device (keyboard = false, D-pad = true).
# Analog-stick directions do NOT come through here — see stick_direction_changed.
signal direction_pressed(direction: int, from_gamepad: bool)
signal direction_released(direction: int, from_gamepad: bool)

# Analog stick: the latched dominant 4-way direction after hysteresis (-1 when
# the stick is released / neutral), plus the raw dominant-stick vector each frame
# it moves (for telemetry gauges).
signal stick_direction_changed(direction: int, magnitude: float)
signal stick_moved(vector: Vector2)

# Normalised buttons. `action` is one of the ids below — named by physical gamepad
# POSITION (Godot's JOY_BUTTON_* layout), never by game meaning, so the vocabulary
# survives across PlayStation / Xbox / Switch / others (Godot maps each pad to the
# same positions; only the printed labels differ):
#   button_a / button_b / button_x / button_y / start / shoulder_left /
#   shoulder_right / trigger_left / trigger_right / stick_left / stick_right.
# Keyboard keys are folded onto their nearest device action so the interpreter only
# ever maps one vocabulary.
signal button_pressed(action: String)
signal button_released(action: String)

# Number row 1..9 (keyboard) — kept distinct from buttons for indexed actions.
signal number_pressed(number: int)

# ------------------------------------------------------------------------------

var _arrow_to_direction := {}
var _wasd_to_direction := {}
var _joypad_dpad_to_direction := {}

# Digital direction press tracking so a release maps back to its source channel.
var _direction_down := {}  # direction -> from_gamepad
# Same idea for face/shoulder/trigger actions (button_a, shoulder_left, …) — tracks
# "is this action currently held" independent of device, so a second joypad device
# mirroring an already-held action (see _emit_direction_pressed) is dropped instead
# of re-emitted.
var _action_down := {}  # action -> true while held

# Source-based keyboard/gamepad dedup (see GAMEPAD_KEY_MIRROR_MS). Timestamps of the
# last processed gamepad button, keyed the same way the keyboard folds, so a mirror can
# be recognised by (same action/direction + within window). The `_dropped_*` sets keep
# press/release paired: a keyboard release is dropped iff its press was dropped, so a
# folded button never leaks a lone release nor a stuck `_direction_down` entry.
var _joy_action_ts := {}           # folded action -> ticks_msec of last gamepad button edge
var _joy_direction_ts := {}        # direction     -> ticks_msec of last D-pad edge
var _dropped_key_actions := {}     # folded action -> true while its keyboard press is suppressed
var _dropped_key_directions := {}  # direction      -> true while its arrow press is suppressed

# Last-active device: which device produced the most recent REAL (non-mirror) event.
# The interpreter reads this to pick face-button meaning (keyboard vs pad) instead of
# mere pad presence — an idle connected controller no longer forces gamepad semantics.
var last_input_was_gamepad: bool = false

# Which joypad device produced the most recent gamepad event (button, trigger or
# stick latch) — -1 while none has fired yet. A game's UI layer reads
# `is_playstation_pad()` off this to print the printed hardware label that matches
# the ACTUAL connected pad (LB/RB on Xbox-style, L1/R1 on PlayStation) instead of
# hardcoding one brand — Godot maps every pad to the same JOY_BUTTON_* positions, but
# the label printed on the plastic differs per brand.
var last_gamepad_device: int = -1

# True when the last-active gamepad's reported name looks like a PlayStation pad
# (DualShock / DualSense / "Wireless Controller", the name Godot/SDL report for a
# PS4/PS5 pad over most backends). Name-sniffing is the only signal Godot exposes
# without a GUID database; false (Xbox-style default) for every other/unknown pad,
# which matches the existing A/B/X/Y + LB/RB glyphs already shipped.
func is_playstation_pad() -> bool:
	if last_gamepad_device == -1:
		return false
	var name := Input.get_joy_name(last_gamepad_device).to_lower()
	return 'playstation' in name or 'dualshock' in name or 'dualsense' in name or 'wireless controller' in name or 'sony' in name

# Timestamp of the most recent gamepad button/trigger/stick-latch event. On a
# keyboard-less device (Steam Deck) `last_input_was_gamepad` is only ever reset to
# false by a KEYBOARD event (see _handle_key) — there is none on the Deck, so that
# bool latches true FOREVER after the first controller press and would wrongly
# reject every later mouse/touch click for the rest of the session (confirmed live:
# it silently broke the Settings close-on-touch guard added the same day). Callers
# that need "was this click likely a same-frame Steam Input phantom mirror of a
# gamepad press" (rather than "is a pad merely connected") should compare against
# THIS timestamp with a short window (~100ms, like GAMEPAD_KEY_MIRROR_MS) instead
# of reading the sticky bool.
var last_gamepad_input_ms: int = 0

# Analog stick state, tracked PER DEVICE (device -> Vector2) rather than in one
# shared pair of floats. Multiple joypads can be connected at once — the Deck's own
# controls plus one or more external pads — and some third-party pads (confirmed
# live: a GameSir G7 Pro) even enumerate as TWO separate devices for the same
# physical stick (native HID + XInput layer), each firing its own motion events. A
# single shared `_left_axis`/`_right_axis` let those fight over the same floats,
# which read as extra "information"/jitter compared to the Deck's own sticks.
# `_update_stick()` now picks the single hardest-pushed stick across every device —
# the same "harder push wins" idea the old left-vs-right logic already used,
# extended across devices so an idle pad's noise can never out-vote the one the
# player is actually holding.
var _left_axis_by_device: Dictionary = {}   # device -> Vector2
var _right_axis_by_device: Dictionary = {}  # device -> Vector2
var _stick_direction: int = -1
var _neutral_pending: bool = false  # a release is being debounced (see STICK_NEUTRAL_DEBOUNCE_MS)

# Set by the game (0..1): how fast the controlled character is moving. 0 keeps the
# precise 45° split (default for menus / other fox games); toward 1 the turn angle
# narrows so a partial flick turns. Lives here because the stick classification lives
# here, but the VALUE is a game concept the interpreter pushes in.
var stick_speed_factor: float = 0.0
# Base = the "main" axis a chicane pivots around (the longest-held recent direction),
# tracked separately from the instantaneous emitted latch.
var _stick_base_direction: int = -1
var _stick_dir_since_ms: int = 0

# Triggers (L2 / R2) are analog axes → edge-detected with hysteresis so each pull
# fires its button once.
var _trigger_left_down: bool = false
var _trigger_right_down: bool = false

# ------------------------------------------------------------------------------

func _ready():
	_arrow_to_direction[KEY_UP] = DIR_TOP
	_arrow_to_direction[KEY_DOWN] = DIR_BOTTOM
	_arrow_to_direction[KEY_LEFT] = DIR_LEFT
	_arrow_to_direction[KEY_RIGHT] = DIR_RIGHT

	_wasd_to_direction[KEY_W] = DIR_TOP
	_wasd_to_direction[KEY_S] = DIR_BOTTOM
	_wasd_to_direction[KEY_A] = DIR_LEFT
	_wasd_to_direction[KEY_D] = DIR_RIGHT

	_joypad_dpad_to_direction[JOY_BUTTON_DPAD_UP] = DIR_TOP
	_joypad_dpad_to_direction[JOY_BUTTON_DPAD_DOWN] = DIR_BOTTOM
	_joypad_dpad_to_direction[JOY_BUTTON_DPAD_LEFT] = DIR_LEFT
	_joypad_dpad_to_direction[JOY_BUTTON_DPAD_RIGHT] = DIR_RIGHT

	for device in Input.get_connected_joypads():
		print('[DIAG Controls] connected at ready: device=', device, ' name=', Input.get_joy_name(device), ' guid=', Input.get_joy_guid(device))
	Input.joy_connection_changed.connect(func(device, connected):
		print('[DIAG Controls] joy_connection_changed device=', device, ' connected=', connected, ' name=', Input.get_joy_name(device))
		if not connected:
			# Drop its stale axis reading — otherwise a disconnected pad's last
			# non-neutral value keeps "winning" _strongest_axis_vector() forever.
			_left_axis_by_device.erase(device)
			_right_axis_by_device.erase(device)
	)
	set_process(true)

# ------------------------------------------------------------------------------

func _input(event):
	if event is InputEventKey:
		_handle_key(event)
	elif event is InputEventJoypadButton:
		_handle_joypad_button(event)
	elif event is InputEventJoypadMotion:
		_handle_joypad_motion(event)
	elif event is InputEventScreenTouch:
		print('[DIAG Controls] RAW ScreenTouch index=', event.index, ' pressed=', event.pressed, ' pos=', event.position)
	elif event is InputEventMouseButton:
		print('[DIAG Controls] RAW MouseButton index=', event.button_index, ' pressed=', event.pressed, ' pos=', event.position)

# ------------------------------------------------------------------------------
# Keyboard
# ------------------------------------------------------------------------------

func _handle_key(event: InputEventKey):
	if event.is_echo():
		return

	# While a text field owns the keyboard, every key that yields a character must reach
	# it as text — never fold WASD onto a move, SPACE / letters onto confirm, or a digit
	# onto a number-select. Arrows / ESC / ENTER carry no character, so they still drive
	# menu navigation, cancel and submit. Checked on press AND release (same keycode both
	# times) so a suppressed press never leaves a dangling release.
	if _is_text_key(event) and _text_input_focused():
		return

	var keycode := event.keycode

	var key_action := _key_to_button(keycode)
	if key_action != '':
		# Steam Deck (and any pad) injects a synthetic keyboard key alongside the
		# real gamepad button (A → SPACE, B → ESCAPE), so one physical press arrives
		# twice and folds to the same action. Drop the keyboard copy ONLY when a
		# gamepad button folding to the same action was just seen (source-based dedup,
		# not mere presence — see GAMEPAD_KEY_MIRROR_MS). A real desktop keypress with
		# no recent gamepad event always goes through, even beside an idle controller.
		if _is_gamepad_mirror_action(key_action, event.pressed):
			print('[DIAG Controls] keyboard key_action=', key_action, ' DROPPED as gamepad mirror, pressed=', event.pressed)
			return
		print('[DIAG Controls] keyboard key_action=', key_action, ' keycode=', keycode, ' pressed=', event.pressed, ' (last_input_was_gamepad was ', last_input_was_gamepad, ')')
		last_input_was_gamepad = false
		if event.pressed:
			_emit_button_pressed(key_action)
		else:
			_emit_button_released(key_action)
		return

	if event.pressed:
		var number := _keycode_to_number(keycode)
		if number > 0:
			last_input_was_gamepad = false
			number_pressed.emit(number)
			return

	var direction := _key_to_direction(event)
	if direction == -1:
		return

	# Steam Deck (and any gamepad) maps the D-pad to BOTH arrow keys and
	# JOY_BUTTON_DPAD, so a single D-pad press arrives twice. Drop the arrow-key copy
	# ONLY when a JOY_BUTTON_DPAD for the same direction was just seen (source-based,
	# not presence). WASD has no D-pad mirror and always stays live for the desktop.
	if keycode in _arrow_to_direction and _is_gamepad_mirror_direction(direction, event.pressed):
		return

	last_input_was_gamepad = false
	if event.pressed:
		_emit_direction_pressed(direction, false)
	else:
		_emit_direction_released(direction, false)

func _key_to_button(keycode: int) -> String:
	# Keyboard keys fold onto their nearest device action (the generic vocabulary):
	# SPACE / ENTER are the primary "accept" → button_a, ESCAPE is "back" → button_b.
	# CTRL mirrors L2 (trigger_left) so the keyboard reaches the same focus action the
	# interpreter binds for the gamepad L2. R folds onto button_y so the keyboard reset
	# shares the gamepad's Y action. SHIFT folds onto button_x (the game reads SHIFT as
	# the pawn swap there); it no longer mirrors R2 — on keyboard the rush lives on
	# button_a (SPACE, carried by the interpreter), so trigger_right is now R2-only.
	match keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER: return 'button_a'
		KEY_ESCAPE: return 'button_b'
		KEY_R: return 'button_y'
		KEY_SHIFT: return 'button_x'
		KEY_CTRL: return 'trigger_left'
		KEY_PAGEUP: return 'shoulder_left'
		KEY_PAGEDOWN: return 'shoulder_right'
	return ''

# True when the key produces a printable character (letters incl. WASD, digits, space),
# so it belongs to a focused text field rather than to a game action. WASD is matched on
# physical position (layout-independent), the rest on the logical keycode.
func _is_text_key(event: InputEventKey) -> bool:
	var kc := event.keycode
	if kc == KEY_SPACE:
		return true
	if kc >= KEY_A and kc <= KEY_Z:
		return true
	if kc >= KEY_0 and kc <= KEY_9:
		return true
	return event.physical_keycode in _wasd_to_direction

# True while a text-input control (LineEdit / TextEdit) holds the GUI keyboard focus.
func _text_input_focused() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var focus := vp.gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit

func _key_to_direction(event: InputEventKey) -> int:
	if event.keycode in _arrow_to_direction:
		return _arrow_to_direction[event.keycode]
	if event.physical_keycode in _wasd_to_direction:
		return _wasd_to_direction[event.physical_keycode]
	return -1

func _keycode_to_number(keycode: int) -> int:
	match keycode:
		KEY_1: return 1
		KEY_2: return 2
		KEY_3: return 3
		KEY_4: return 4
		KEY_5: return 5
		KEY_6: return 6
		KEY_7: return 7
		KEY_8: return 8
		KEY_9: return 9
	return 0

# True when this keyboard event folding onto `action` is the Steam Input synthetic
# mirror of a real gamepad button (same action within GAMEPAD_KEY_MIRROR_MS). The
# press decides; the release just follows its press so the pair never desyncs.
func _is_gamepad_mirror_action(action: String, pressed: bool) -> bool:
	if pressed:
		var ts: int = _joy_action_ts.get(action, -1)
		if ts != -1 and Time.get_ticks_msec() - ts <= GAMEPAD_KEY_MIRROR_MS:
			_dropped_key_actions[action] = true
			return true
		_dropped_key_actions.erase(action)
		return false
	if _dropped_key_actions.get(action, false):
		_dropped_key_actions.erase(action)
		return true
	return false

# Same source-based dedup for the D-pad → arrow-key mirror, keyed by direction. Dropping
# a mirror release when (and only when) its press was dropped keeps `_direction_down`
# balanced, so a dropped D-pad copy never leaves a phantom held direction.
func _is_gamepad_mirror_direction(direction: int, pressed: bool) -> bool:
	if pressed:
		var ts: int = _joy_direction_ts.get(direction, -1)
		if ts != -1 and Time.get_ticks_msec() - ts <= GAMEPAD_KEY_MIRROR_MS:
			_dropped_key_directions[direction] = true
			return true
		_dropped_key_directions.erase(direction)
		return false
	if _dropped_key_directions.get(direction, false):
		_dropped_key_directions.erase(direction)
		return true
	return false

# ------------------------------------------------------------------------------
# Joypad buttons
# ------------------------------------------------------------------------------

func _handle_joypad_button(event: InputEventJoypadButton):
	var button := event.button_index
	print('[DIAG Controls] joypad button_index=', button, ' pressed=', event.pressed, ' device=', event.device)
	# A gamepad button is the source of truth for the mirror dedup below and marks the
	# pad as the last-active device (set BEFORE any emit so the interpreter reads it).
	last_input_was_gamepad = true
	last_gamepad_device = event.device
	var now := Time.get_ticks_msec()
	last_gamepad_input_ms = now

	var direction: int = _joypad_dpad_to_direction.get(button, -1)
	if direction != -1:
		_joy_direction_ts[direction] = now
		if event.pressed:
			_emit_direction_pressed(direction, true)
		else:
			_emit_direction_released(direction, true)
		return

	var action := _joypad_button_to_action(button)
	if action == '':
		return
	_joy_action_ts[action] = now
	if event.pressed:
		_emit_button_pressed(action)
	else:
		_emit_button_released(action)

# Idempotent action emit (see `_action_down` doc) — shared by the keyboard and
# joypad button paths so a duplicate source (synthetic keyboard mirror already
# filtered upstream, OR a second joypad device — e.g. a GameSir G7 Pro's native
# HID + XInput layers both reporting the same press) can never double-fire.
func _emit_button_pressed(action: String) -> void:
	if _action_down.get(action, false):
		return
	print('[DIAG Controls] EMITTED button_pressed action=', action)
	_action_down[action] = true
	button_pressed.emit(action)

func _emit_button_released(action: String) -> void:
	if not _action_down.get(action, false):
		return
	print('[DIAG Controls] EMITTED button_released action=', action)
	_action_down.erase(action)
	button_released.emit(action)

func _joypad_button_to_action(button: int) -> String:
	match button:
		JOY_BUTTON_A: return 'button_a'
		JOY_BUTTON_B: return 'button_b'
		JOY_BUTTON_X: return 'button_x'
		JOY_BUTTON_Y: return 'button_y'
		JOY_BUTTON_START: return 'start'
		JOY_BUTTON_LEFT_SHOULDER: return 'shoulder_left'
		JOY_BUTTON_RIGHT_SHOULDER: return 'shoulder_right'
		JOY_BUTTON_LEFT_STICK: return 'stick_left'
		JOY_BUTTON_RIGHT_STICK: return 'stick_right'
	return ''

# ------------------------------------------------------------------------------
# Directions — shared press/release with source tracking
# ------------------------------------------------------------------------------

func _emit_direction_pressed(direction: int, from_gamepad: bool):
	# Idempotent on an already-held direction. Some third-party pads (confirmed live:
	# a GameSir G7 Pro) enumerate as TWO separate joypad devices at once — one native
	# HID interface, one XInput-compatibility layer — and mirror every D-pad press on
	# BOTH device indices. `_direction_down` already tracks "is this direction held"
	# per direction (not per device), so re-pressing an already-held direction is
	# always a duplicate/mirror, never a real second push — drop it instead of
	# re-emitting, or a single physical press reads downstream as two hold_started
	# (a menu cursor jumping two items, an extra confirm sound) per SESSION diagnosis.
	if _direction_down.has(direction):
		return
	print('[DIAG Controls] EMITTED direction_pressed direction=', direction)
	_direction_down[direction] = from_gamepad
	direction_pressed.emit(direction, from_gamepad)

func _emit_direction_released(direction: int, from_gamepad: bool):
	if not _direction_down.has(direction):
		return
	_direction_down.erase(direction)
	direction_released.emit(direction, from_gamepad)

# ------------------------------------------------------------------------------
# Joypad motion — analog stick (hysteresis) + analog triggers (edge)
# ------------------------------------------------------------------------------

# DIAG — counts raw motion events per device over a rolling window so we can
# compare event VOLUME between devices (e.g. Deck's own sticks vs an external
# pad) without flooding the log with a print per axis tick. Flushed by _process.
var _diag_motion_count: Dictionary = {}   # device -> count since last flush
var _diag_motion_elapsed: float = 0.0

# DIAG — peak trigger value (L2/R2) per device over the same rolling window, so we
# can see whether a pad's analog triggers actually reach STICK_ENGAGE (0.5) at all
# (e.g. a different resting/max range under Steam Input) without flooding the log.
var _diag_trigger_peak: Dictionary = {}  # "device:L"/"device:R" -> peak value since last flush

func _process(delta: float) -> void:
	_diag_motion_elapsed += delta
	if _diag_motion_elapsed < 1.0:
		return
	_diag_motion_elapsed = 0.0
	if not _diag_motion_count.is_empty():
		for device in _diag_motion_count:
			print('[DIAG Controls] motion events/s device=', device, ' count=', _diag_motion_count[device])
		_diag_motion_count.clear()
	if not _diag_trigger_peak.is_empty():
		for key in _diag_trigger_peak:
			print('[DIAG Controls] trigger peak/s ', key, '=', _diag_trigger_peak[key])
		_diag_trigger_peak.clear()

func _diag_track_trigger_peak(device: int, side: String, value: float) -> void:
	var key := str(device) + ':' + side
	if value > float(_diag_trigger_peak.get(key, 0.0)):
		_diag_trigger_peak[key] = value

func _handle_joypad_motion(event: InputEventJoypadMotion):
	_diag_motion_count[event.device] = int(_diag_motion_count.get(event.device, 0)) + 1
	match event.axis:
		JOY_AXIS_TRIGGER_LEFT:
			_diag_track_trigger_peak(event.device, 'L', event.axis_value)
			_handle_trigger(event.axis_value, true, event.device)
			return
		JOY_AXIS_TRIGGER_RIGHT:
			_diag_track_trigger_peak(event.device, 'R', event.axis_value)
			_handle_trigger(event.axis_value, false, event.device)
			return
		JOY_AXIS_LEFT_X:
			_set_axis(_left_axis_by_device, event.device, event.axis_value, true)
		JOY_AXIS_LEFT_Y:
			_set_axis(_left_axis_by_device, event.device, event.axis_value, false)
		JOY_AXIS_RIGHT_X:
			_set_axis(_right_axis_by_device, event.device, event.axis_value, true)
		JOY_AXIS_RIGHT_Y:
			_set_axis(_right_axis_by_device, event.device, event.axis_value, false)
		_:
			return
	_update_stick()

func _set_axis(by_device: Dictionary, device: int, value: float, is_x: bool) -> void:
	var v: Vector2 = by_device.get(device, Vector2.ZERO)
	if is_x:
		v.x = value
	else:
		v.y = value
	by_device[device] = v

func _handle_trigger(value: float, is_left: bool, device: int):
	var action := 'trigger_left' if is_left else 'trigger_right'
	var down: bool = _trigger_left_down if is_left else _trigger_right_down
	if value >= STICK_ENGAGE and not down:
		if is_left:
			_trigger_left_down = true
		else:
			_trigger_right_down = true
		last_input_was_gamepad = true
		last_gamepad_device = device
		last_gamepad_input_ms = Time.get_ticks_msec()
		_emit_button_pressed(action)
	elif value < STICK_RELEASE and down:
		if is_left:
			_trigger_left_down = false
		else:
			_trigger_right_down = false
		last_input_was_gamepad = true
		last_gamepad_device = device
		last_gamepad_input_ms = Time.get_ticks_msec()
		_emit_button_released(action)

# Strongest-push-wins across BOTH sticks AND every connected device. Merging axes
# into one shared pair of floats let an idle stick's (or an idle second device's)
# per-frame drift overwrite the active one, dropping magnitude below RELEASE every
# frame → a flood of re-latches. Comparing by magnitude instead means whichever
# stick the player is actually holding always dominates any other idle noise.
var _diag_strongest_device: int = -1  # which device's axis won the last pick

func _strongest_axis_vector() -> Vector2:
	var best := Vector2.ZERO
	var best_device := -1
	for device in _left_axis_by_device:
		var v: Vector2 = _left_axis_by_device[device]
		if v.length() > best.length():
			best = v
			best_device = device
	for device in _right_axis_by_device:
		var v: Vector2 = _right_axis_by_device[device]
		if v.length() > best.length():
			best = v
			best_device = device
	_diag_strongest_device = best_device
	return best

func _update_stick():
	var vector := _strongest_axis_vector()
	var magnitude := vector.length()
	stick_moved.emit(vector)

	var desired := _stick_direction
	if magnitude < STICK_RELEASE:
		desired = -1
	elif magnitude >= STICK_ENGAGE or (_stick_direction != -1 and magnitude >= STICK_TURN):
		# From neutral, ENGAGE is required (drift can't latch on its own); once
		# engaged, a turn re-aims down to STICK_TURN so it lands as soon as the
		# dominant axis flips, not after climbing back past ENGAGE.
		desired = _classify_stick_direction(vector)

	if desired == _stick_direction:
		# Re-deflected before a pending release committed → keep the latch alive.
		if _neutral_pending:
			print('[DIAG Controls] stick debounce CANCELLED (re-deflected) magnitude=', magnitude, ' device=', _diag_strongest_device)
		_neutral_pending = false
		return

	if desired == -1:
		# Debounce the release: a flick through the centre must not read as a
		# release + re-press. Hold the current latch; a cardinal re-engaging
		# within the window becomes a direct turn, else _commit_neutral fires.
		if not _neutral_pending:
			print('[DIAG Controls] stick debounce START magnitude=', magnitude, ' device=', _diag_strongest_device, ' held_direction=', _stick_direction)
			_neutral_pending = true
			get_tree().create_timer(STICK_NEUTRAL_DEBOUNCE_MS / 1000.0).timeout.connect(_commit_neutral)
		return

	_neutral_pending = false
	_latch_stick(desired, magnitude)

func _commit_neutral():
	if not _neutral_pending:
		return
	_neutral_pending = false
	# The stick may have re-engaged without a fresh motion event — re-check live.
	var vector := _strongest_axis_vector()
	if vector.length() >= STICK_RELEASE:
		return
	_latch_stick(-1, 0.0)

func _latch_stick(direction: int, magnitude: float):
	if direction == _stick_direction:
		return
	print('[DIAG Controls] stick latch: ', _stick_direction, ' -> ', direction, ' magnitude=', magnitude, ' device=', _diag_strongest_device)
	if direction != -1:
		last_input_was_gamepad = true
		last_gamepad_device = _diag_strongest_device
		last_gamepad_input_ms = Time.get_ticks_msec()
	_stick_direction = direction
	# Restart the base-commit clock on every latch and drop the base on release, so
	# the base only ever follows a direction that PERSISTS (see _classify).
	_stick_dir_since_ms = Time.get_ticks_msec()
	if direction == -1:
		_stick_base_direction = -1
	stick_direction_changed.emit(direction, magnitude)

# Speed-adaptive 4-way classification. At rest (stick_speed_factor 0) it is the plain
# 45° quadrant split. As speed rises, the angle a turn must deflect from the BASE axis
# shrinks (STICK_TURN_ANGLE_SLOW → _FAST), so a partial diagonal flick turns the
# character with far less stick travel. The base is the longest-held direction, NOT
# the latest latch, so a chicane (brief perpendicular taps) pivots around the main
# axis instead of resetting the reference on every tap.
func _classify_stick_direction(vector: Vector2) -> int:
	# Promote the base once the current latch has persisted past the commit window:
	# a real direction change, not a brief chicane tap.
	if _stick_direction != -1 and (Time.get_ticks_msec() - _stick_dir_since_ms) >= BASE_COMMIT_MS:
		_stick_base_direction = _stick_direction

	# Fresh from neutral (no base yet): neutral 45° split, no bias.
	if _stick_base_direction == -1:
		if absf(vector.x) > absf(vector.y):
			return DIR_RIGHT if vector.x > 0.0 else DIR_LEFT
		return DIR_BOTTOM if vector.y > 0.0 else DIR_TOP

	# Turn threshold measured from the base axis. k = tan(angle): at 45° k = 1 (the
	# neutral split); below 45° k < 1, so the perpendicular wins with less deflection.
	var turn_angle := lerpf(STICK_TURN_ANGLE_SLOW, STICK_TURN_ANGLE_FAST, clampf(stick_speed_factor, 0.0, 1.0))
	var k := tan(deg_to_rad(turn_angle))

	if _stick_base_direction == DIR_RIGHT or _stick_base_direction == DIR_LEFT:
		if absf(vector.y) > absf(vector.x) * k:
			return DIR_BOTTOM if vector.y > 0.0 else DIR_TOP
		return DIR_RIGHT if vector.x > 0.0 else DIR_LEFT
	if absf(vector.x) > absf(vector.y) * k:
		return DIR_RIGHT if vector.x > 0.0 else DIR_LEFT
	return DIR_BOTTOM if vector.y > 0.0 else DIR_TOP
