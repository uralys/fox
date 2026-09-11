class_name SettingsSectionData
extends Resource

# ==============================================================================
# SettingsSectionData — shared settings leaf (fox/components/settings).
#
# Mutualised from the two games that carried a byte-identical copy. fox is a
# shared symlink, so this `class_name` is visible in every consuming game; any
# local copy of the same class_name would collide. Each game's
# settings-data.tres points its `path=` here while keeping the shared `uid=`
# (uid://lq8iyk7ammmv).
# ==============================================================================

@export var label_key: String = ''
# Literal fallback when `label_key` is untranslated (see SettingsToggleData).
@export var label_text: String = ''
@export var toggles: Array[SettingsToggleData] = []
