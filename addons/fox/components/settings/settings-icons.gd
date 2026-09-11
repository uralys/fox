extends RefCounted

# ==============================================================================
# settings-icons.gd — the shared icon set of the settings screen (fox).
#
# The same SVGs faraday-corridors wears in its console, moved into fox so every
# game lights the same destination with the same logo instead of falling back to
# a letter. A game names a channel `steam` and gets the Steam glyph; it can still
# pass its own `icon` on the data resource to override.
#
# Each SVG carries an explicit 128px intrinsic size: fox gitignores `.import`
# files, so every consuming project regenerates them and `svg/scale` cannot be
# relied on — the size has to live in the asset itself. 128px keeps a 32px glyph
# crisp at a 1.5× handheld content scale.
# ==============================================================================

const _DIR := 'res://addons/fox/assets/settings-icons/'

# Channel id → logo. Ids match SettingsThemeData.CHANNEL_COLORS.
const CHANNELS := {
	'artists': _DIR + 'artists.svg',
	'bluesky': _DIR + 'bluesky.svg',
	'discord': _DIR + 'discord.svg',
	'fox': _DIR + 'fox.svg',
	'godot': _DIR + 'godot.svg',
	'spotify': _DIR + 'spotify.svg',
	'steam': _DIR + 'steam.svg',
	'uralys': _DIR + 'uralys.svg',
}

# Toggle id → glyph. `music` and `sounds` are the two channels every fox game
# has; the rest cover the options a game commonly adds.
const TOGGLES := {
	'music': _DIR + 'music-note.svg',
	'sounds': _DIR + 'speaker.svg',
	'sound_effects': _DIR + 'speaker.svg',
	'interface': _DIR + 'interface.svg',
	'display': _DIR + 'eye.svg',
	'rush': _DIR + 'flame.svg',
}

const GLOBE := _DIR + 'globe.svg'
const GEAR := _DIR + 'gear.svg'

static func channel(id: String) -> Texture2D:
	return _load(CHANNELS.get(id, ''))

static func toggle(id: String) -> Texture2D:
	return _load(TOGGLES.get(id, ''))

static func globe() -> Texture2D:
	return _load(GLOBE)

static func _load(path: String) -> Texture2D:
	if path == '' or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
