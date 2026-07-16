extends Label

# ==============================================================================
# section-label.gd — DISPOSABLE default section header for the settings popup.
#
# Reference skin only: the game supplies its own titled label through its
# `_make_section_label` override. This default just renders the translated
# `label_key` with the default Godot theme (no game design-system tokens).
# ==============================================================================

@export var label_key: String = ''

func _ready() -> void:
	if label_key != '':
		text = tr(label_key)
