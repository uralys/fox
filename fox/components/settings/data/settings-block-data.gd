class_name SettingsBlockData
extends Resource

# ==============================================================================
# SettingsBlockData — one "connect block" of the settings view: an intro line
# above a row of outbound links (fox/components/settings).
#
# This is the credits / social half of the faraday settings console, generalised:
#
#   "A game by Uralys"        → Bluesky · Steam · Uralys
#   "Music by ..."            → Spotify · Artists
#   "Built with ..."          → Godot · Fox
#
# `intro_key` is a translation key; when the project ships no translation for it
# (`tr()` returns the key unchanged), `intro_text` is rendered instead — a bare
# starter game therefore reads correctly without a translations CSV.
# ==============================================================================

@export var intro_key: String = ''
@export var intro_text: String = ''
@export var channels: Array[SettingsChannelData] = []
