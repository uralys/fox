extends HBoxContainer

# ==============================================================================
# settings-footer.gd — DISPOSABLE default footer for the settings popup.
#
# Reference skin only: the game builds its own footer (version dot, hairline,
# privacy link…) via its `_build_footer` override. This default shows the version
# text and, when a link is provided, a plain LinkButton — default Godot theme, no
# game design-system tokens.
# ==============================================================================

@export var version_text: String = ''
@export var link_text: String = ''
@export var link_url: String = ''

func _ready() -> void:
	add_theme_constant_override('separation', 12)

	var version := Label.new()
	version.text = version_text
	version.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(version)

	if link_text != '':
		var link := LinkButton.new()
		link.text = link_text
		link.focus_mode = Control.FOCUS_NONE
		var url := link_url
		link.pressed.connect(func() -> void:
			if url != '':
				OS.shell_open(url))
		add_child(link)
