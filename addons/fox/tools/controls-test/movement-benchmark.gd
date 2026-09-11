extends RefCounted

# ==============================================================================
# Movement benchmark - a headless simulation of a grid pawn's rush model, driven
# by the same direction-hold events as the timeline, used to measure cadence per
# input source x mode and to A/B-test stick-response fixes off the gameplay code.
#
# Shipped with the fox controls test view and loaded by path (const preload), so
# it stays an internal helper of the component rather than a global symbol.
#
# The rush model is a launch duration that ramps to a top speed over `accel_cells`
# cells, plus the cancel / release-grace decision that tells a tap from a rush.
# Every constant is EXPOSED and editable so a tuning screen can experiment
# without touching gameplay code.
# ==============================================================================

# Tunable rush model (defaults: the cadence a grid game converged on).
var launch_s: float = 0.18
var top_s: float = 0.06
var accel_cells: int = 2
var cancel_ms: int = 200
var release_grace_ms: int = 75
var gamepad_grace_ms: int = 150

const TRACK_CELLS := 18

# Stick-model preview params: the two candidate alternatives to the tween-rush,
# tunable here so cadence can be compared before touching any input code.
# Milliseconds.
var repeat_initial_ms: int = 250  # Option 2: dwell before auto-repeat
var repeat_interval_ms: int = 120 # Option 2: per-cell interval (~8.3 c/s)
var arm_ms: int = 200             # Option 1: hold before rush arms

# Live simulation state.
var pos: float = 0.0
var moving: bool = false
var continuous: bool = false
var dir_held: bool = false
var hold_count: int = 0

var _move_start_ms: int = 0
var _move_dur_ms: int = 0
var _from_cell: int = 0
var _to_cell: int = 0
var _hold_start_ms: int = 0
var _grace_until_ms: int = 0
var _last_cell_ms: int = 0

var cur_source: String = 'KB'
var cur_gamepad: bool = false
var cur_mag: float = 0.0
var push_cells: int = 0

# Metrics: bucket key "SOURCE/MODE" → {pushes, cells, intervals[]}.
var _buckets: Dictionary = {}

# ------------------------------------------------------------------------------

func reset_metrics():
	_buckets.clear()

func hold_started(source: String, is_gamepad: bool, magnitude: float, now: int):
	cur_source = source
	cur_gamepad = is_gamepad
	cur_mag = magnitude
	dir_held = true

	# Re-engage during release grace, or a turn while already rushing: keep the
	# hot hold_count, so intermittent stick taps stay pinned at top speed.
	if continuous:
		if not moving:
			_begin_move(now)
		return

	hold_count = 0
	_hold_start_ms = now
	continuous = true
	push_cells = 0
	_last_cell_ms = 0
	_begin_move(now)

func hold_ended(now: int):
	dir_held = false
	if not continuous:
		return
	var held_for = now - _hold_start_ms
	if held_for < cancel_ms:
		# Retroactive single-cell tap (NORMAL).
		_finalize_push('NORMAL')
		continuous = false
	else:
		# Rush release → grace window before the rush actually ends (RUSH).
		var grace = gamepad_grace_ms if cur_gamepad else release_grace_ms
		_grace_until_ms = now + grace

func tick(now: int):
	if moving and now >= _move_start_ms + _move_dur_ms:
		pos = float(_to_cell % TRACK_CELLS)
		moving = false
		if continuous and dir_held:
			_begin_move(now)
	if continuous and not dir_held and now >= _grace_until_ms:
		_finalize_push('RUSH')
		continuous = false
	if moving:
		var t = float(now - _move_start_ms) / float(max(1, _move_dur_ms))
		pos = lerpf(float(_from_cell), float(_to_cell), clampf(t, 0.0, 1.0))

func _begin_move(now: int):
	if moving:
		return
	_move_dur_ms = int(round(_dur_ms()))
	_from_cell = int(round(pos))
	_to_cell = _from_cell + 1
	_move_start_ms = now
	moving = true
	if _last_cell_ms > 0:
		_bucket_for(_provisional_mode()).intervals.append(now - _last_cell_ms)
		_trim(_bucket_for(_provisional_mode()).intervals)
	_last_cell_ms = now
	hold_count += 1
	push_cells += 1

func _dur_ms() -> float:
	var n = hold_count
	if n == 0:
		return launch_s * 1000.0
	if n >= accel_cells:
		return top_s * 1000.0
	var v0 = 1.0 / launch_s
	var v_max = 1.0 / top_s
	var v = lerpf(v0, v_max, float(n) / float(accel_cells))
	return 1000.0 / v

func _provisional_mode() -> String:
	return 'RUSH' if push_cells > 1 else 'NORMAL'

func _finalize_push(mode: String):
	var b = _bucket_for(mode)
	b.pushes += 1
	b.cells += push_cells

func _bucket_for(mode: String) -> Dictionary:
	var key = cur_source + '/' + mode
	if not _buckets.has(key):
		_buckets[key] = {pushes = 0, cells = 0, intervals = []}
	return _buckets[key]

func _trim(arr: Array):
	while arr.size() > 40:
		arr.pop_front()

# ------------------------------------------------------------------------------
# Read API for the display

func current_mode() -> String:
	if not continuous:
		return '-'
	return _provisional_mode()

func dwell_ms(now: int) -> int:
	if not continuous:
		return 0
	return now - _hold_start_ms

func bucket(source: String, mode: String) -> Dictionary:
	return _buckets.get(source + '/' + mode, {pushes = 0, cells = 0, intervals = []})

func cells_per_s(source: String, mode: String) -> float:
	var ms = ms_per_cell(source, mode)
	return 0.0 if ms <= 0.0 else 1000.0 / ms

func ms_per_cell(source: String, mode: String) -> float:
	var iv = bucket(source, mode).intervals
	if iv.is_empty():
		return 0.0
	var sum = 0.0
	for v in iv:
		sum += v
	return sum / iv.size()

func cells_per_push(source: String, mode: String) -> float:
	var b = bucket(source, mode)
	return 0.0 if b.pushes == 0 else float(b.cells) / float(b.pushes)

# ------------------------------------------------------------------------------
# Stick-model comparison — cells produced for a given hold dwell under each model.
# 'current' = today's tween-rush; 'repeat' = Option 2; 'arm' = Option 1.

# Cells whose tween has STARTED within `dwell_ms` under the shared rush ramp
# (cell 0 launch 180ms, velocity-lerp to 60ms over accel_cells).
func _rush_cells(dwell_ms: int) -> int:
	if dwell_ms <= 0:
		return 1
	var t := 0.0
	var n := 0
	while t <= float(dwell_ms) and n < 256:
		n += 1
		var c := n - 1
		var dur: float
		if c == 0:
			dur = launch_s * 1000.0
		elif c >= accel_cells:
			dur = top_s * 1000.0
		else:
			var v = lerpf(1.0 / launch_s, 1.0 / top_s, float(c) / float(accel_cells))
			dur = 1000.0 / v
		t += dur
	return n

func model_cells(model: String, dwell_ms: int) -> int:
	match model:
		'repeat':
			if dwell_ms < repeat_initial_ms:
				return 1
			return 2 + int(float(dwell_ms - repeat_initial_ms) / float(repeat_interval_ms))
		'arm':
			if dwell_ms < arm_ms:
				return 1
			return 1 + _rush_cells(dwell_ms - arm_ms)
		_:
			return _rush_cells(dwell_ms)

func model_cps(model: String) -> float:
	match model:
		'repeat':
			return 1000.0 / float(repeat_interval_ms)
		_:
			return 1.0 / top_s
