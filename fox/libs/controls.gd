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

# Stick hysteresis: a firm push past ENGAGE latches the dominant 4-way direction;
# it only re-arms once the stick falls back below RELEASE. The gap between the two
# is the neutral band that keeps drift from latching on its own. Values are
# community-aligned (Godot deadzone / XInput anti-drift).
const STICK_ENGAGE: float = 0.5
const STICK_RELEASE: float = 0.25

# Local 4-way ids (no dependency on a project's LevelState). Same convention as
# the flat grid: TOP=0, RIGHT=1, BOTTOM=2, LEFT=3.
const DIR_TOP: int = 0
const DIR_RIGHT: int = 1
const DIR_BOTTOM: int = 2
const DIR_LEFT: int = 3

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

# Analog stick state (left + right tracked independently; the harder push wins).
var _left_axis: Vector2 = Vector2.ZERO
var _right_axis: Vector2 = Vector2.ZERO
var _stick_direction: int = -1

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

# ------------------------------------------------------------------------------

func _input(event):
	if event is InputEventKey:
		_handle_key(event)
	elif event is InputEventJoypadButton:
		_handle_joypad_button(event)
	elif event is InputEventJoypadMotion:
		_handle_joypad_motion(event)

# ------------------------------------------------------------------------------
# Keyboard
# ------------------------------------------------------------------------------

func _handle_key(event: InputEventKey):
	if event.is_echo():
		return

	var keycode := event.keycode

	var key_action := _key_to_button(keycode)
	if key_action != '':
		if event.pressed:
			button_pressed.emit(key_action)
		else:
			button_released.emit(key_action)
		return

	if event.pressed:
		var number := _keycode_to_number(keycode)
		if number > 0:
			number_pressed.emit(number)
			return

	var direction := _key_to_direction(event)
	if direction == -1:
		return

	# Steam Deck (and any gamepad) maps the D-pad to BOTH arrow keys and
	# JOY_BUTTON_DPAD, so a single D-pad press arrives twice. When a joypad is
	# connected, drop the arrow-key copy — the JOY_BUTTON_DPAD path is the source
	# of truth. WASD stays for the desktop keyboard.
	if keycode in _arrow_to_direction and not Input.get_connected_joypads().is_empty():
		return

	if event.pressed:
		_emit_direction_pressed(direction, false)
	else:
		_emit_direction_released(direction, false)

func _key_to_button(keycode: int) -> String:
	# Keyboard keys fold onto their nearest device action (the generic vocabulary):
	# SPACE / ENTER are the primary "accept" → button_a, ESCAPE is "back" → button_b.
	match keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER: return 'button_a'
		KEY_ESCAPE: return 'button_b'
		KEY_R: return 'trigger_left'
		KEY_SHIFT: return 'shoulder_right'
	return ''

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

# ------------------------------------------------------------------------------
# Joypad buttons
# ------------------------------------------------------------------------------

func _handle_joypad_button(event: InputEventJoypadButton):
	var button := event.button_index

	var direction: int = _joypad_dpad_to_direction.get(button, -1)
	if direction != -1:
		if event.pressed:
			_emit_direction_pressed(direction, true)
		else:
			_emit_direction_released(direction, true)
		return

	var action := _joypad_button_to_action(button)
	if action == '':
		return
	if event.pressed:
		button_pressed.emit(action)
	else:
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

func _handle_joypad_motion(event: InputEventJoypadMotion):
	match event.axis:
		JOY_AXIS_TRIGGER_LEFT:
			_handle_trigger(event.axis_value, true)
			return
		JOY_AXIS_TRIGGER_RIGHT:
			_handle_trigger(event.axis_value, false)
			return
		JOY_AXIS_LEFT_X:
			_left_axis.x = event.axis_value
		JOY_AXIS_LEFT_Y:
			_left_axis.y = event.axis_value
		JOY_AXIS_RIGHT_X:
			_right_axis.x = event.axis_value
		JOY_AXIS_RIGHT_Y:
			_right_axis.y = event.axis_value
		_:
			return
	_update_stick()

func _handle_trigger(value: float, is_left: bool):
	var action := 'trigger_left' if is_left else 'trigger_right'
	var down: bool = _trigger_left_down if is_left else _trigger_right_down
	if value >= STICK_ENGAGE and not down:
		if is_left:
			_trigger_left_down = true
		else:
			_trigger_right_down = true
		button_pressed.emit(action)
	elif value < STICK_RELEASE and down:
		if is_left:
			_trigger_left_down = false
		else:
			_trigger_right_down = false
		button_released.emit(action)

func _update_stick():
	# Track both sticks and follow whichever is pushed harder. Merging them into
	# one vector lets an idle stick's per-frame drift overwrite the active one,
	# dropping magnitude below RELEASE every frame → a flood of re-latches.
	var vector := _left_axis if _left_axis.length() >= _right_axis.length() else _right_axis
	var magnitude := vector.length()
	stick_moved.emit(vector)

	var desired := _stick_direction
	if magnitude < STICK_RELEASE:
		desired = -1
	elif magnitude >= STICK_ENGAGE:
		if absf(vector.x) > absf(vector.y):
			desired = DIR_RIGHT if vector.x > 0.0 else DIR_LEFT
		else:
			desired = DIR_BOTTOM if vector.y > 0.0 else DIR_TOP

	if desired == _stick_direction:
		return
	_stick_direction = desired
	stick_direction_changed.emit(desired, magnitude)
