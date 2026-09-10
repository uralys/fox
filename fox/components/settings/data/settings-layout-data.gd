class_name SettingsLayoutData
extends Resource

# ==============================================================================
# SettingsLayoutData — the WHOLE settings view of a fox game, in one resource
# (fox/components/settings).
#
# It is the generic counterpart of the per-game `SettingsData` a mature project
# ends up writing (faraday-corridors has its own, with named sections): here the
# two columns are plain arrays, so a starter game describes its console without
# declaring a single class.
#
#   left column   → `sections`  : audio / display / gameplay toggles (+ volume bars)
#   right column  → `blocks`    : credits & social link rows
#   footer        → version · language · privacy
#
# A game never has to fill this by hand from an editor: `SettingsLayoutData.new()`
# plus a few appends in GDScript is a complete, valid layout.
# ==============================================================================

@export var title_key: String = 'settings.title'
@export var title_text: String = 'SETTINGS'

@export_group('Columns')
@export var sections: Array[SettingsSectionData] = []
@export var blocks: Array[SettingsBlockData] = []

@export_group('Footer')
# Shown as `version_prefix + G.VERSION` when the game exposes one, else as-is.
@export var version_prefix: String = 'v'
@export var privacy_url: String = ''
@export var privacy_key: String = 'settings.footer.privacy'
@export var privacy_text: String = 'Privacy'
# Locale codes offered by the language switcher, e.g. ['en', 'fr', 'de'].
# Fewer than two entries hides the switcher entirely.
@export var languages: PackedStringArray = PackedStringArray()
