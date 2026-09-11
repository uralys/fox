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

const _Theme := preload('res://addons/fox/components/settings/data/settings-theme-data.gd')
const _SettingsText := preload('res://addons/fox/components/settings/settings-text.gd')
const _Link := preload('res://addons/fox/components/settings/ui/settings-link.gd')
const _Icons := preload('res://addons/fox/components/settings/settings-icons.gd')

var theme_data: SettingsThemeData = null
# Optional `{select, focus, switch}` Callables, passed on to every socket.
var sfx: Dictionary = {}

var _links: Array = []

func build(block: SettingsBlockData) -> void:
	if theme_data == null:
		theme_data = _Theme.new()

	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override('separation', int(theme_data.block_text_gap))

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
	row.add_theme_constant_override('separation', int(theme_data.hex_gap))
	add_child(row)

	for channel in block.channels:
		if channel == null:
			continue
		var link := _Link.new()
		link.theme_data = theme_data
		link.sfx = sfx
		link.url = channel.url
		link.label_key = channel.label_key
		link.label_text = channel.label_text
		# A channel that names a known destination inherits the shared logo and the
		# shared colour, so two games linking Steam light it the same way.
		link.icon = channel.icon if channel.icon != null else _Icons.channel(channel.id)
		link.color = channel.color if channel.color.a > 0.0 else theme_data.channel_color(channel.id)
		row.add_child(link)
		_links.append(link)

# The sockets of this block, in reading order — one navigation row.
func links() -> Array:
	return _links
