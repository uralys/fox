class_name JuicyButton
extends Button

# ==============================================================================
# JuicyButton — Button with the shared JuicyPress squish on down/up.
# Sound feedback (hover/focus/press cues) is opt-in and wired only when the
# game's Sound autoload exposes the matching methods, so games without those
# cues (or without the Sound autoload) run unaffected.
# ==============================================================================

@export var press_scale: Vector2 = JuicyPress.DEFAULT_PRESS_SCALE
@export var restore_duration: float = JuicyPress.DEFAULT_RESTORE_DURATION

var _tween: Tween
# The idle `normal` stylebox set aside while `set_focused` lends it the hover look.
var _unfocused_normal: StyleBox = null
var _focused: bool = false

func _ready():
	JuicyPress.setup_pivot(self)
	resized.connect(func(): JuicyPress.setup_pivot(self))

	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

	_wire_sound()

func _wire_sound() -> void:
	var sound := get_node_or_null(^'/root/Sound')
	if sound == null:
		return
	if sound.has_method('play_select'):
		mouse_entered.connect(sound.play_select)
		pressed.connect(sound.play_select)
	if sound.has_method('play_focus_select'):
		focus_entered.connect(sound.play_focus_select)

# Keyboard / gamepad focus driven by a navigator (MenuNavigator), not Godot's
# native focus: a native focus would also let the engine's own ui_* actions press
# the button a second time. The focused button wears its own hover look, so the
# highlight reads the same whether it was reached by mouse or by directional input.
func set_focused(focused: bool, silent: bool = false) -> void:
	if _focused == focused:
		return
	_focused = focused
	if focused:
		_unfocused_normal = get_theme_stylebox('normal')
		add_theme_stylebox_override('normal', get_theme_stylebox('hover'))
		if not silent:
			var sound := get_node_or_null(^'/root/Sound')
			if sound != null and sound.has_method('play_focus_select'):
				sound.play_focus_select()
		return
	# A restyle while focused (a mode button turning active) already replaced the
	# borrowed look: putting the stale idle box back would undo it.
	if get_theme_stylebox('normal') == get_theme_stylebox('hover') and _unfocused_normal != null:
		add_theme_stylebox_override('normal', _unfocused_normal)
	_unfocused_normal = null

func is_focused() -> bool:
	return _focused

func _on_button_down():
	JuicyPress.press(self, _tween, press_scale)

func _on_button_up():
	_tween = JuicyPress.release(self, restore_duration)
