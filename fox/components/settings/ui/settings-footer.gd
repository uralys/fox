extends HBoxContainer

# ==============================================================================
# settings-footer.gd — the footer line of the shared settings view (fox).
#
#   ● v1.2.0                              🌐 Français · Privacy
#
# Left: a build stamp — the single most useful line a player can quote in a bug
# report. Right: the language switcher and the privacy link, the two footnotes
# that belong to every shipped game rather than to any one of them.
#
# The footer decides nothing: it emits `language_pressed` / `privacy_pressed` and
# lets the screen base apply the locale and rebuild. Its two links are handed back
# through `links()` so they join the navigation grid as its last row.
# ==============================================================================

const _Theme := preload('res://fox/components/settings/data/settings-theme-data.gd')
const _SettingsText := preload('res://fox/components/settings/settings-text.gd')
const _TextLink := preload('res://fox/components/settings/ui/settings-text-link.gd')

signal language_pressed
signal privacy_pressed

var theme_data: SettingsThemeData = null

var version_text: String = ''
# Current locale code; empty hides the language switcher.
var language_code: String = ''
var privacy_key: String = ''
var privacy_text: String = ''
var privacy_url: String = ''

var _links: Array = []

func build() -> void:
	if theme_data == null:
		theme_data = _Theme.new()

	add_theme_constant_override('separation', 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# A game with no version stamped in project.godot shows no stamp at all: an
	# empty `v` next to a bullet reads as a bug, not as a build.
	if version_text != '':
		add_child(_build_version())

	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override('separation', 12)
	add_child(right)

	if language_code != '':
		var language := _make_link(_SettingsText.endonym(language_code), true)
		language.activated.connect(func() -> void: language_pressed.emit())
		right.add_child(language)

	if privacy_url != '':
		if language_code != '':
			right.add_child(_make_separator())
		var privacy := _make_link(_SettingsText.resolve(privacy_key, privacy_text), false)
		privacy.activated.connect(func() -> void: privacy_pressed.emit())
		right.add_child(privacy)

# The footer links, left to right — the console's last navigation row.
func links() -> Array:
	return _links

# ------------------------------------------------------------------------------

func _build_version() -> Control:
	var box := HBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override('separation', 8)

	var dot := Control.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.draw.connect(func() -> void:
		dot.draw_circle(Vector2(5, 5), 5.0, theme_data.accent)
	)
	box.add_child(dot)

	var label := Label.new()
	label.text = version_text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	theme_data.apply_font(
		label, theme_data.font_body, theme_data.version_size, theme_data.accent_at(0.7)
	)
	box.add_child(label)
	return box

func _make_link(text: String, globe: bool) -> Control:
	var link := _TextLink.new()
	link.theme_data = theme_data
	link.text = text
	link.show_globe = globe
	_links.append(link)
	return link

func _make_separator() -> Control:
	var dot := Label.new()
	dot.text = '·'
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	theme_data.apply_font(
		dot, theme_data.font_body, theme_data.footer_size, theme_data.accent_at(0.4)
	)
	return dot
