extends CheckButton

# ==============================================================================
# settings-toggle.gd — DISPOSABLE default toggle for the shared settings popup.
#
# Reference skin only: the real toggle (custom draw, arc-burst, ice palette…)
# lives in the consuming game and is instanced by that game's `_make_toggle`
# override. This default is a plain CheckButton so a bare game has a functional,
# navigable toggle with the default Godot theme (no game design-system tokens).
#
# FOCUS CONTRACT (duck-typed, expected by SettingsPopupBase navigation):
#   signal value_changed(value: bool)
#   set_navigation_focused(value: bool, silent := false)
#   toggle_value()
# Any game toggle-skin must expose the same three members to be navigable.
#
# `icon` / `initial_value` / `label_key` are set by `_bind_toggle` in the base;
# `icon` reuses the built-in Button icon slot, `label_key` feeds the button text.
# ==============================================================================

signal value_changed(value: bool)

@export var label_key: String = ''
@export var initial_value: bool = false

func _ready() -> void:
	if label_key != '':
		text = tr(label_key)
	focus_mode = Control.FOCUS_ALL
	# Seed the state BEFORE wiring `toggled`, so the initial value is not re-emitted.
	button_pressed = initial_value
	toggled.connect(func(on: bool) -> void: value_changed.emit(on))

# ── Focus contract ──

func set_navigation_focused(value: bool, _silent: bool = false) -> void:
	if value:
		grab_focus()
	else:
		release_focus()

func toggle_value() -> void:
	button_pressed = not button_pressed

# ── Value access (parity with a game skin) ──

func get_value() -> bool:
	return button_pressed

func set_value(value: bool) -> void:
	button_pressed = value
