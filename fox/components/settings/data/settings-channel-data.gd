class_name SettingsChannelData
extends Resource

# ==============================================================================
# SettingsChannelData — shared settings leaf (fox/components/settings).
#
# Mutualised from the two games that carried a byte-identical copy. fox is a
# shared symlink, so this `class_name` is visible in every consuming game; any
# local copy of the same class_name would collide. Each game's
# settings-data.tres points its `path=` here while keeping the shared `uid=`
# (uid://dye8bq7me7hr7).
# ==============================================================================

@export var id: String = ''
@export var label_key: String = ''
@export var icon: Texture2D
@export var url: String = ''
@export var color: Color = Color.WHITE
@export var em_text_key: String = ''
