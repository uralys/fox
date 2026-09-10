extends Control

# ==============================================================================
# settings-toggle.gd — the option row of the shared settings screen (fox).
#
#   [icon] gap [label] expand [On/Off] gap [switch + thumb + arc-burst]
#
# This is faraday-corridors' SettingsToggle, moved into fox as-is: the octagonal
# track, the tweened thumb with its halo, the ON glow on the border, the
# arc-burst ring with its eight radial sparks, the label that shrinks rather than
# running under the switch. Only two things changed on the way in:
#
#   * every dimension reads `theme_data` (SettingsThemeData) instead of the
#     game's DesignTokens — the numbers are the same, the source is shared;
#   * the sounds go through `sfx`, a Dictionary of optional Callables the screen
#     fills, because fox may not name a game's Sound autoload.
#
# FOCUS CONTRACT (duck-typed, expected by the screen base's navigation):
#   signal value_changed(value: bool)
#   set_navigation_focused(value: bool, silent := false)
#   toggle_value() / nudge(direction)
# ==============================================================================

const _Theme := preload('res://fox/components/settings/data/settings-theme-data.gd')
const _SettingsText := preload('res://fox/components/settings/settings-text.gd')
const _NavFocus := preload('res://fox/components/settings/ui/nav-focus.gd')

signal value_changed(value: bool)

@export var icon: Texture2D
# Icon variant painted when the toggle is Off (muted). Falls back to `icon`.
@export var icon_off: Texture2D
# Icon tint override (transparent = the accent colour).
@export var icon_tint: Color = Color(0, 0, 0, 0)
@export var label_key: String = ''
@export var label_text: String = ''
@export var initial_value: bool = false

var theme_data: SettingsThemeData = null
# Optional `{select, focus, switch}` Callables, filled by the screen.
var sfx: Dictionary = {}

var _value: bool = false
var _thumb_t: float = 0.0       # 0.0 = off, 1.0 = on
var _track_alpha: float = 0.10
var _border_alpha: float = 0.35
var _hovered: bool = false
# Gamepad/keyboard cursor highlight, independent from mouse hover.
var _nav_focused: bool = false

# Arc-burst / spark FX (driven by _process when active)
var _burst_active: bool = false
var _burst_elapsed: float = 0.0

var _switch_rect: Rect2 = Rect2()

const BURST_DURATION := 0.45
const BURST_RADIUS := 36.0
const THUMB_DURATION := 0.25
const THUMB_TRAVEL_OFF := 5.0
const THUMB_TRAVEL_ON := 39.0
const TRACK_CUT := 8.0
const STATE_GAP := 14.0
const STATE_SIZE := 14
const NAV_FOCUS_WHITE_BLEND := 0.85

# ── Lifecycle ──

func _ready() -> void:
	if theme_data == null:
		theme_data = _Theme.new()
	custom_minimum_size = Vector2(0, theme_data.toggle_height)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	_value = initial_value
	_thumb_t = 1.0 if _value else 0.0
	_track_alpha = theme_data.toggle_track_alpha_on if _value else theme_data.toggle_track_alpha_off
	_border_alpha = 1.0 if _value else theme_data.toggle_border_alpha_off
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(_on_resized)
	set_process(false)
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

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_toggle()
			accept_event()
	elif event is InputEventKey:
		var k: InputEventKey = event
		if k.pressed and (k.keycode == KEY_SPACE or k.keycode == KEY_ENTER):
			_toggle()
			accept_event()

# ── Public API ──

func set_value(value: bool, emit: bool = true, animate: bool = true) -> void:
	if value == _value:
		return
	_value = value
	var target_t: float = 1.0 if _value else 0.0
	var target_track: float = theme_data.toggle_track_alpha_on if _value \
		else theme_data.toggle_track_alpha_off
	var target_border: float = 1.0 if _value else theme_data.toggle_border_alpha_off
	if animate and is_inside_tree():
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_method(_set_thumb_t, _thumb_t, target_t, THUMB_DURATION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw.tween_method(_set_track_alpha, _track_alpha, target_track, THUMB_DURATION)
		tw.tween_method(_set_border_alpha, _border_alpha, target_border, THUMB_DURATION)
	else:
		_thumb_t = target_t
		_track_alpha = target_track
		_border_alpha = target_border
		queue_redraw()
	if _value:
		_start_burst()
	if emit:
		value_changed.emit(_value)

func get_value() -> bool:
	return _value

# Cursor highlight from the screen's gamepad/keyboard navigation. Ticks the focus
# sound on gain (silent on the initial selection).
func set_navigation_focused(value: bool, silent: bool = false) -> void:
	if _nav_focused == value:
		return
	_nav_focused = value
	_NavFocus.apply_scale(self, value)
	if value and not silent:
		_play('focus')
	queue_redraw()

# Directional set (gamepad / D-pad left-right): left → Off, right → On.
func nudge(direction: int) -> void:
	var target: bool = direction > 0
	if target == _value:
		return
	set_value(target)
	_play('switch')

# Confirm (gamepad A / Enter): flip the switch.
func toggle_value() -> void:
	_toggle()

# ── Internals ──

func _toggle() -> void:
	# Apply the value first so the switch sound respects the new state: turning
	# sound effects ON is heard, turning them OFF is silent.
	set_value(not _value)
	_play('switch')

func _play(key: String) -> void:
	var hook: Variant = sfx.get(key)
	if hook is Callable and (hook as Callable).is_valid():
		(hook as Callable).call()

func _set_thumb_t(v: float) -> void:
	_thumb_t = v
	queue_redraw()

func _set_track_alpha(v: float) -> void:
	_track_alpha = v
	queue_redraw()

func _set_border_alpha(v: float) -> void:
	_border_alpha = v
	queue_redraw()

func _start_burst() -> void:
	_burst_active = true
	_burst_elapsed = 0.0
	set_process(true)

func _process(delta: float) -> void:
	if not _burst_active:
		set_process(false)
		return
	_burst_elapsed += delta
	if _burst_elapsed >= BURST_DURATION:
		_burst_active = false
		_burst_elapsed = 0.0
		set_process(false)
	queue_redraw()

# ── Draw ──

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	# Gamepad/keyboard focus lights the whole row white (mouse hover keeps accent).
	var accent: Color = theme_data.accent
	if _nav_focused:
		accent = accent.lerp(Color.WHITE, NAV_FOCUS_WHITE_BLEND)

	# Switch geometry — right edge aligned, vertically centered.
	var sw: float = theme_data.toggle_switch_size.x
	var sh: float = theme_data.toggle_switch_size.y
	var switch_x: float = w - sw
	var switch_y: float = (h - sh) * 0.5
	_switch_rect = Rect2(switch_x, switch_y, sw, sh)

	# Icon (left side, vertically centered).
	var icon_size: float = theme_data.toggle_icon_size
	var icon_y: float = (h - icon_size) * 0.5
	var draw_icon: Texture2D = icon if (_value or icon_off == null) else icon_off
	if draw_icon != null:
		var icon_alpha: float = 1.0 if _value else 0.65
		if _hovered or _nav_focused:
			icon_alpha = minf(1.0, icon_alpha + 0.15)
		var base_tint: Color = accent if icon_tint.a <= 0.0 else icon_tint
		draw_texture_rect(
			draw_icon, Rect2(0, icon_y, icon_size, icon_size), false,
			Color(base_tint.r, base_tint.g, base_tint.b, icon_alpha)
		)

	var font: Font = theme_data.font_title
	if font == null:
		font = ThemeDB.fallback_font

	# State text (just left of the switch). Computed before the label so the label
	# can be clipped to the room left of it — a long translation then shrinks
	# instead of running under the state text and the switch.
	var state_text: String = 'On' if _value else 'Off'
	var state_size: Vector2 = font.get_string_size(
		state_text, HORIZONTAL_ALIGNMENT_LEFT, -1, STATE_SIZE
	)
	var state_color: Color = Color(accent, 0.85 if _value else 0.55)
	var state_x: float = switch_x - STATE_GAP - state_size.x

	var label: String = _SettingsText.resolve(label_key, label_text)
	var label_font_size: int = theme_data.label_size
	var label_x: float = icon_size + theme_data.toggle_gap_icon
	var label_max_w: float = maxf(1.0, state_x - STATE_GAP - label_x)
	var label_size: Vector2 = font.get_string_size(
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size
	)
	if label_size.x > label_max_w:
		label_font_size = maxi(10, int(label_font_size * label_max_w / label_size.x))
		label_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size)
	var label_alpha: float = 0.78
	if _hovered or _nav_focused:
		label_alpha = 1.0
	elif _value:
		label_alpha = 0.92
	var label_y: float = (h + label_size.y * 0.65) * 0.5
	draw_string(
		font, Vector2(label_x, label_y), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size, Color(theme_data.text, label_alpha)
	)

	var state_y: float = (h + state_size.y * 0.65) * 0.5
	draw_string(
		font, Vector2(state_x, state_y), state_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, STATE_SIZE, state_color
	)

	# Switch track (octagonal).
	var track_pts: PackedVector2Array = OctagonGeom.points(_switch_rect, TRACK_CUT)
	draw_colored_polygon(track_pts, Color(accent, _track_alpha))
	var track_closed: PackedVector2Array = PackedVector2Array(track_pts)
	track_closed.append(track_pts[0])
	# Outer glow when ON.
	if _border_alpha > theme_data.toggle_border_alpha_off + 0.01:
		draw_polyline(
			track_closed,
			Color(accent, (_border_alpha - theme_data.toggle_border_alpha_off) * 0.55), 3.5
		)
	draw_polyline(track_closed, Color(accent, _border_alpha), 1.2)

	# Thumb (filled disc + halo).
	var thumb_r: float = theme_data.toggle_thumb_diameter * 0.5
	var thumb_off_x: float = switch_x + THUMB_TRAVEL_OFF + thumb_r
	var thumb_on_x: float = switch_x + THUMB_TRAVEL_ON + thumb_r
	var thumb_x: float = lerpf(thumb_off_x, thumb_on_x, _thumb_t)
	var thumb_y: float = switch_y + sh * 0.5
	if _thumb_t > 0.0:
		Dot.draw(self, Vector2(thumb_x, thumb_y), thumb_r * 1.6, Color(accent, 0.20 * _thumb_t))
	var thumb_color: Color = Color(accent, 1.0).lerp(theme_data.text_dim, 1.0 - _thumb_t)
	thumb_color.a = 1.0
	Dot.draw(self, Vector2(thumb_x, thumb_y), thumb_r, thumb_color)

	if _burst_active:
		_draw_burst(switch_x + sw * 0.5, switch_y + sh * 0.5)

# Electric ring expanding from the switch on flip → true, plus 8 radial sparks.
func _draw_burst(cx: float, cy: float) -> void:
	var t: float = clampf(_burst_elapsed / BURST_DURATION, 0.0, 1.0)
	var accent: Color = theme_data.accent

	var sw: float = theme_data.toggle_switch_size.x
	var sh: float = theme_data.toggle_switch_size.y
	var scale_t: float = lerpf(0.5, 1.4, t)
	var ring_alpha: float = lerpf(1.0, 0.0, t)
	var half_w: float = (sw * 0.5 + BURST_RADIUS * 0.30) * scale_t
	var half_h: float = (sh * 0.5 + BURST_RADIUS * 0.30) * scale_t
	var ring_rect := Rect2(cx - half_w, cy - half_h, half_w * 2.0, half_h * 2.0)
	var ring_pts: PackedVector2Array = OctagonGeom.points(ring_rect, 12.0 * scale_t)
	var ring_closed: PackedVector2Array = PackedVector2Array(ring_pts)
	ring_closed.append(ring_pts[0])
	draw_polyline(ring_closed, Color(accent, ring_alpha * 0.35), 5.0)
	draw_polyline(ring_closed, Color(accent, ring_alpha), 1.5)

	var spark_dur: float = maxf(0.001, BURST_DURATION - 0.05)
	var spark_t: float = clampf(_burst_elapsed / spark_dur, 0.0, 1.0)
	var spark_alpha: float = lerpf(1.0, 0.0, spark_t)
	var spark_dist: float = lerpf(0.0, 24.0, spark_t)
	var n: int = 8
	for i in n:
		var ang: float = (TAU / n) * i
		var point := Vector2(cx + cos(ang) * spark_dist, cy + sin(ang) * spark_dist)
		Dot.draw(self, point, 4.0, Color(accent, spark_alpha * 0.35))
		Dot.draw(self, point, 2.0, Color(accent, spark_alpha))
