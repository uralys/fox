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

func _on_button_down():
	JuicyPress.press(self, _tween, press_scale)

func _on_button_up():
	_tween = JuicyPress.release(self, restore_duration)
