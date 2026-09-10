extends Control

# ==============================================================================
# settings-volume-bar.gd — the volume slider row of the settings screen (fox).
#
#   [octagonal track + chamfered fill + thumb] gap [percentage]
#
# faraday-corridors' SettingsVolumeBar, moved into fox as-is: the octagonal-cut
# track, the fill chamfered on its left end and cut straight at the value, the
# thumb disc with its halo, the right-aligned readout. Only the token source and
# the sound hooks changed on the way in (see settings-toggle.gd).
#
# It only appears when the game's binding for that channel declares a
# `volume_get` / `volume_set` pair.
#
# FOCUS CONTRACT (duck-typed): `set_navigation_focused`, `nudge(direction)`.
# `toggle_value()` is deliberately absent — confirming on a slider does nothing.
# ==============================================================================

const _Theme := preload('res://fox/components/settings/data/settings-theme-data.gd')
const _NavFocus := preload('res://fox/components/settings/ui/nav-focus.gd')

signal value_changed(value: float)

@export var initial_value: float = 0.75

var theme_data: SettingsThemeData = null
# Optional `{select, focus, switch}` Callables, filled by the screen.
var sfx: Dictionary = {}

var _value: float = 0.75
var _hovered: bool = false
var _dragging: bool = false
var _nav_focused: bool = false

# Cached track geometry (updated each _draw, reused for hit-testing).
var _track_rect: Rect2 = Rect2()

const TRACK_CUT := 4.0
const THUMB_RADIUS := 8.0
const BORDER_ALPHA := 0.55
const NAV_FOCUS_WHITE_BLEND := 0.85

# ── Lifecycle ──

func _ready() -> void:
	if theme_data == null:
		theme_data = _Theme.new()
	custom_minimum_size = Vector2(0, theme_data.volume_height)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	_value = clampf(initial_value, 0.0, 1.0)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(_on_resized)
	queue_redraw()

func _on_resized() -> void:
	_NavFocus.apply_scale(self, _nav_focused)
	queue_redraw()

func _on_mouse_entered() -> void:
	_hovered = true
	_play('select')
	queue_redraw()

func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()

# ── Public API ──

func set_value(value: float, emit: bool = true) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(clamped, _value):
		return
	_value = clamped
	queue_redraw()
	if emit:
		value_changed.emit(_value)

func get_value() -> float:
	return _value

func set_navigation_focused(value: bool, silent: bool = false) -> void:
	if _nav_focused == value:
		return
	_nav_focused = value
	_NavFocus.apply_scale(self, value)
	if value and not silent:
		_play('focus')
	queue_redraw()

# Directional adjust (gamepad / D-pad left-right): one step per push.
func nudge(direction: int) -> void:
	_user_set_value(_value + float(direction) * theme_data.volume_step)

# ── Input ──

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_set_from_x(mb.position.x)
				accept_event()
			else:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		_set_from_x(event.position.x)
		accept_event()
	elif event is InputEventKey:
		var k: InputEventKey = event
		if k.pressed and k.keycode == KEY_LEFT:
			_user_set_value(_value - theme_data.volume_step)
			accept_event()
		elif k.pressed and k.keycode == KEY_RIGHT:
			_user_set_value(_value + theme_data.volume_step)
			accept_event()

func _set_from_x(x: float) -> void:
	if _track_rect.size.x <= 0.0:
		return
	_user_set_value((x - _track_rect.position.x) / _track_rect.size.x)

# User-driven change (drag / keyboard): apply, and tick the switch sound on a
# real change. Programmatic set_value() calls (init, toggle sync) stay silent.
func _user_set_value(value: float) -> void:
	var before: float = _value
	set_value(value)
	if not is_equal_approx(before, _value):
		_play('switch')

func _play(key: String) -> void:
	var hook: Variant = sfx.get(key)
	if hook is Callable and (hook as Callable).is_valid():
		(hook as Callable).call()

# ── Draw ──

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	# Gamepad/keyboard focus lights the whole row white (mouse hover keeps accent).
	var accent: Color = theme_data.accent
	if _nav_focused:
		accent = accent.lerp(Color.WHITE, NAV_FOCUS_WHITE_BLEND)

	var font: Font = theme_data.font_title
	if font == null:
		font = ThemeDB.fallback_font

	# Percentage readout, right-aligned (matches the toggle's state text).
	var pct_text: String = str(int(round(_value * 100.0))) + '%'
	var pct_size: int = theme_data.value_size
	var pct_metrics: Vector2 = font.get_string_size(
		pct_text, HORIZONTAL_ALIGNMENT_LEFT, -1, pct_size
	)
	var pct_color: Color = Color(accent, 0.85 if (_hovered or _nav_focused) else 0.65)
	var pct_x: float = w - pct_metrics.x
	var pct_y: float = (h + pct_metrics.y * 0.65) * 0.5
	draw_string(
		font, Vector2(pct_x, pct_y), pct_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, pct_size, pct_color
	)

	# Track geometry — a small left margin, up to the percentage.
	var track_x: float = theme_data.volume_margin_left
	var track_right: float = pct_x - theme_data.volume_value_gap
	var track_w: float = maxf(0.0, track_right - track_x)
	var track_h: float = theme_data.volume_track_height
	var track_y: float = (h - track_h) * 0.5
	_track_rect = Rect2(track_x, track_y, track_w, track_h)
	if track_w <= 0.0:
		return

	# Track background (octagonal, low alpha).
	var track_pts: PackedVector2Array = OctagonGeom.points(_track_rect, TRACK_CUT)
	draw_colored_polygon(track_pts, Color(accent, theme_data.volume_track_alpha))
	var track_closed: PackedVector2Array = PackedVector2Array(track_pts)
	track_closed.append(track_pts[0])
	draw_polyline(track_closed, Color(accent, BORDER_ALPHA), 1.0)

	# Fill — left end chamfered like the track, right end straight at the value.
	var fill_w: float = track_w * _value
	if fill_w > TRACK_CUT:
		var fr: float = track_x + fill_w
		draw_colored_polygon(PackedVector2Array([
			Vector2(track_x + TRACK_CUT, track_y),
			Vector2(fr, track_y),
			Vector2(fr, track_y + track_h),
			Vector2(track_x + TRACK_CUT, track_y + track_h),
			Vector2(track_x, track_y + track_h - TRACK_CUT),
			Vector2(track_x, track_y + TRACK_CUT),
		]), Color(accent, theme_data.volume_fill_alpha))

	# Thumb (filled disc + halo) at the fill boundary.
	var thumb := Vector2(track_x + fill_w, track_y + track_h * 0.5)
	if _hovered or _dragging or _nav_focused:
		Dot.draw(self, thumb, THUMB_RADIUS * 1.6, Color(accent, 0.20))
	Dot.draw(self, thumb, THUMB_RADIUS, Color(accent, 1.0))
