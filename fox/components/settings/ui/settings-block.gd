extends VBoxContainer

# ==============================================================================
# settings-block.gd — one credits / social block of the settings view (fox).
#
#   A game by Uralys
#      ⬡      ⬡      ⬡
#    Bluesky  Steam  Uralys
#
# An intro line above a centred row of link sockets. Stacking three of these in
# the right column is the whole credits half of the console: who made the game,
# where its music lives, what it is built with.
#
# The block owns nothing but layout: the sockets it creates are handed back
# through `links()` so the popup base can register them as one navigation row.
# ==============================================================================

const _Theme := preload('res://fox/components/settings/data/settings-theme-data.gd')
const _SettingsText := preload('res://fox/components/settings/settings-text.gd')
const _Link := preload('res://fox/components/settings/ui/settings-link.gd')

var theme_data: SettingsThemeData = null

var _links: Array = []

func build(block: SettingsBlockData) -> void:
	if theme_data == null:
		theme_data = _Theme.new()

	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override('separation', 8)

	var intro := Label.new()
	intro.text = _SettingsText.resolve(block.intro_key, block.intro_text)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	theme_data.apply_font(intro, theme_data.font_body, theme_data.intro_size, theme_data.text_at(0.85))
	add_child(intro)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override('separation', 10)
	add_child(row)

	for channel in block.channels:
		if channel == null:
			continue
		var link := _Link.new()
		link.theme_data = theme_data
		link.icon = channel.icon
		link.url = channel.url
		link.label_key = channel.label_key
		link.label_text = channel.label_text
		link.color = channel.color if channel.color.a > 0.0 else theme_data.accent
		row.add_child(link)
		_links.append(link)

# The sockets of this block, in reading order — one navigation row.
func links() -> Array:
	return _links
