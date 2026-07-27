class_name MenuNavigator
extends RefCounted

# ==============================================================================
# MenuNavigator — shared keyboard / gamepad focus cursor for menus.
#
# Any menu (option lists, grids, carousels, rating chains) tends to hand-roll the
# exact same cursor: read a unified "direction hold" signal, walk an ordered list
# or a grid, highlight the focused item, play a tick, and confirm on a "tap". This
# factors that loop out once, with zero coupling to a specific game.
#
# Model: a ragged grid of focusables (`_rows`, an Array of rows, each a row of
# items). A flat 1D list is just a single row (horizontal) or one item per row
# (vertical); a rectangular grid is built from a flat list via `set_grid`;
# irregular layouts (a row with a variable number of affordances) use `set_rows`
# directly. Focus is a `(row, col)` pair; `col` is clamped into the target row on
# a vertical move.
#
# Per-axis policy: `_wrap_horizontal` / `_wrap_vertical` pick wrap vs clamp
# independently, so different menus can wrap or clamp on each axis as they need.
#
# Escape hatch: `_interceptor` is given first shot at every direction and may fully
# own it (e.g. nudge a volume bar or cross columns on LEFT/RIGHT). Returning `true`
# skips the built-in move. Hosts that keep an external hold-repeat call
# `move_horizontal` / `move_vertical` straight, bypassing the interceptor they
# already resolved.
#
# Input is NOT read raw here: directions are the fox Controls contract
# (`Controls.DIR_*`), and the host injects the actual "direction hold" and "tap"
# signals through `attach(direction_signal, tapped_signal)` — the navigator never
# reaches for a game-specific autoload. Highlight and tick are Callables the host
# supplies (`set_highlight` / `set_sound`); both default to no-ops.
# ==============================================================================

signal focus_changed(row: int, col: int)

# Ragged grid of focusables and the parallel row-major flat list (for grids / 1D
# lists that address items by a single index).
var _rows: Array = []
var _flat: Array = []

# Cursor.
var _focus_row: int = 0
var _focus_col: int = 0

# Per-axis movement policy (false = clamp at the edges, true = wrap around).
var _wrap_horizontal: bool = false
var _wrap_vertical: bool = false

# Highlight applied to an item: `func(item, focused: bool) -> void`. Injected by
# the host (e.g. a center-preserving scale); no-op until set.
var _highlight: Callable = Callable()

# Tick played on a genuine (non-silent) focus change: `func() -> void`. Injected by
# the host; no-op until set.
var _sound: Callable = Callable()

# Optional confirm on the host-supplied "tap" signal: `func() -> void` (the host
# reads the current focus via `focus_row` / `focus_col` / `focus_flat_index`).
var _confirm: Callable = Callable()

# Optional first-shot direction handler: `func(direction: int) -> bool`. Return `true`
# to consume the direction and skip the built-in move.
var _interceptor: Callable = Callable()

# Signals wired through attach() and remembered for a symmetric detach().
var _direction_signal: Signal = Signal()
var _tapped_signal: Signal = Signal()

# ------------------------------------------------------------------------------
# Content
# ------------------------------------------------------------------------------

# Ragged grid: `rows` is an Array of rows, each row an Array of focusable items.
func set_rows(rows: Array) -> void:
	_rows = rows
	_rebuild_flat()
	_clamp_cursor()

# Rectangular grid built row-major from a flat list (fixed column count).
func set_grid(items: Array, columns: int) -> void:
	var cols := maxi(1, columns)
	var rows: Array = []
	var row: Array = []
	for item in items:
		row.append(item)
		if row.size() == cols:
			rows.append(row)
			row = []
	if not row.is_empty():
		rows.append(row)
	set_rows(rows)

# Single horizontal row — LEFT/RIGHT walk it, UP/DOWN are inert.
func set_row(items: Array) -> void:
	set_rows([items] if not items.is_empty() else [])

# Single vertical column — one item per row, UP/DOWN walk it, LEFT/RIGHT are inert.
func set_column(items: Array) -> void:
	var rows: Array = []
	for item in items:
		rows.append([item])
	set_rows(rows)

func set_wrap(horizontal: bool, vertical: bool) -> void:
	_wrap_horizontal = horizontal
	_wrap_vertical = vertical

func set_highlight(callback: Callable) -> void:
	_highlight = callback

func set_sound(callback: Callable) -> void:
	_sound = callback

func set_confirm(callback: Callable) -> void:
	_confirm = callback

# `func(direction: int) -> bool` — return `true` to consume the direction.
func set_direction_interceptor(callback: Callable) -> void:
	_interceptor = callback

func clear() -> void:
	_rows = []
	_flat = []
	_focus_row = 0
	_focus_col = 0

# ------------------------------------------------------------------------------
# Lifecycle — idempotent connect / disconnect of the host-supplied signals.
# `direction_signal` carries a direction int (Controls.DIR_*); `tapped_signal`
# (optional) triggers `_confirm`. Both are remembered so detach() is symmetric.
# ------------------------------------------------------------------------------

func attach(direction_signal: Signal, tapped_signal: Signal = Signal(), connect_confirm: bool = true) -> void:
	_direction_signal = direction_signal
	if not direction_signal.is_null() and not direction_signal.is_connected(_on_direction):
		direction_signal.connect(_on_direction)
	_tapped_signal = tapped_signal
	if connect_confirm and _confirm.is_valid() and not tapped_signal.is_null():
		if not tapped_signal.is_connected(_on_tapped):
			tapped_signal.connect(_on_tapped)

func detach() -> void:
	if not _direction_signal.is_null() and _direction_signal.is_connected(_on_direction):
		_direction_signal.disconnect(_on_direction)
	if not _tapped_signal.is_null() and _tapped_signal.is_connected(_on_tapped):
		_tapped_signal.disconnect(_on_tapped)

# ------------------------------------------------------------------------------
# Focus
# ------------------------------------------------------------------------------

# Silent initial seed — lights the first cell without a tick (an involuntary move,
# not a genuine player action).
func seed(row: int = 0, col: int = 0) -> void:
	_apply_focus(row, col, true, true)

# `force` re-applies the highlight even when the cursor already points at (row, col):
# needed when two coordinated navigators share one highlight layer (left / right
# columns) and the destination cell happens to match the stale cursor from a
# previous visit — the item was blurred on leave, so it must be re-lit on return.
func set_focus(row: int, col: int, silent: bool = false, force: bool = false) -> void:
	_apply_focus(row, col, silent, force)

func set_focus_flat(index: int, silent: bool = false) -> void:
	if index < 0 or index >= _flat.size():
		return
	var rc: Vector2i = _flat[index]
	_apply_focus(rc.x, rc.y, silent, false)

# Mouse hover mirrors the same cursor: point at the hovered item so pad-navigation
# and the mouse never fight over the highlight. No-op if the item is not tracked.
func focus_item(item: Variant, silent: bool = true) -> void:
	for r in _rows.size():
		var idx := (_rows[r] as Array).find(item)
		if idx != -1:
			_apply_focus(r, idx, silent, false)
			return

# ------------------------------------------------------------------------------
# Moves — `navigate` runs the interceptor first; the axis helpers bypass it (for a
# host-owned hold-repeat that already resolved the direction).
# ------------------------------------------------------------------------------

func navigate(direction: int) -> void:
	if _interceptor.is_valid() and bool(_interceptor.call(direction)):
		return
	match direction:
		Controls.DIR_TOP:
			move_vertical(-1)
		Controls.DIR_BOTTOM:
			move_vertical(1)
		Controls.DIR_LEFT:
			move_horizontal(-1)
		Controls.DIR_RIGHT:
			move_horizontal(1)

func move_horizontal(delta: int) -> void:
	if _rows.is_empty() or delta == 0:
		return
	var count: int = (_rows[_focus_row] as Array).size()
	var col := _step_axis(_focus_col, delta, count, _wrap_horizontal)
	_apply_focus(_focus_row, col, false, false)

func move_vertical(delta: int) -> void:
	if _rows.is_empty() or delta == 0:
		return
	var row := _step_axis(_focus_row, delta, _rows.size(), _wrap_vertical)
	var col := clampi(_focus_col, 0, maxi(0, (_rows[row] as Array).size() - 1))
	_apply_focus(row, col, false, false)

# ------------------------------------------------------------------------------
# Accessors
# ------------------------------------------------------------------------------

func focus_row() -> int:
	return _focus_row

func focus_col() -> int:
	return _focus_col

# Row-major index into the flat list, or -1 when there is no focus / no content.
func focus_flat_index() -> int:
	for i in _flat.size():
		var rc: Vector2i = _flat[i]
		if rc.x == _focus_row and rc.y == _focus_col:
			return i
	return -1

func current_item() -> Variant:
	if _focus_row < 0 or _focus_row >= _rows.size():
		return null
	var row: Array = _rows[_focus_row]
	if _focus_col < 0 or _focus_col >= row.size():
		return null
	return row[_focus_col]

func is_empty() -> bool:
	return _flat.is_empty()

func count() -> int:
	return _flat.size()

# ------------------------------------------------------------------------------
# Internals
# ------------------------------------------------------------------------------

func _on_direction(direction: int) -> void:
	navigate(direction)

func _on_tapped() -> void:
	if _confirm.is_valid():
		_confirm.call()

func _apply_focus(row: int, col: int, silent: bool, force: bool) -> void:
	if _rows.is_empty():
		return
	row = clampi(row, 0, _rows.size() - 1)
	col = clampi(col, 0, maxi(0, (_rows[row] as Array).size() - 1))
	if not force and row == _focus_row and col == _focus_col:
		return

	var previous: Variant = current_item()
	_focus_row = row
	_focus_col = col
	var current: Variant = current_item()

	if _highlight.is_valid():
		if previous != null and previous != current:
			_highlight.call(previous, false)
		if current != null:
			_highlight.call(current, true)

	if not silent and _sound.is_valid():
		_sound.call()

	focus_changed.emit(_focus_row, _focus_col)

func _step_axis(index: int, delta: int, count: int, wrap: bool) -> int:
	if count <= 0:
		return 0
	var value := index + delta
	if wrap:
		return ((value % count) + count) % count
	return clampi(value, 0, count - 1)

func _rebuild_flat() -> void:
	_flat = []
	for r in _rows.size():
		var row: Array = _rows[r]
		for c in row.size():
			_flat.append(Vector2i(r, c))

func _clamp_cursor() -> void:
	if _rows.is_empty():
		_focus_row = 0
		_focus_col = 0
		return
	_focus_row = clampi(_focus_row, 0, _rows.size() - 1)
	_focus_col = clampi(_focus_col, 0, maxi(0, (_rows[_focus_row] as Array).size() - 1))
