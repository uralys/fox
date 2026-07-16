extends PanelContainer

# ==============================================================================
# settings-frame.gd — DISPOSABLE default chassis for the shared settings popup.
#
# This is a reference skin, NOT the real one: the actual chassis (glass frame,
# custom geometry, whatever the game wants) lives in the consuming game and is
# injected through the base's `_make_frame()`. This default exists only so a bare
# game gets a working, closeable popup out of the box. Strictly skin-agnostic:
# the default Godot theme, no custom colours / geometry / game design-system.
#
# Contract expected by the base (duck-typed):
#   signal close_requested
#   add_section(control: Control)
#   on_viewport_resized()
# ==============================================================================

signal close_requested

var _content: VBoxContainer

func _ready() -> void:
	_ensure_built()

func _ensure_built() -> void:
	if _content != null:
		return

	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var root := VBoxContainer.new()
	root.add_theme_constant_override('separation', 12)
	add_child(root)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close_button := Button.new()
	close_button.text = '✕'
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close_button)
	root.add_child(header)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override('separation', 16)
	root.add_child(_content)

func add_section(control: Control) -> void:
	_ensure_built()
	_content.add_child(control)

# Hook mirroring the game skin's frame: the default theme reflows on its own, so
# there is nothing to recompute here. Games override the frame entirely.
func on_viewport_resized() -> void:
	pass
