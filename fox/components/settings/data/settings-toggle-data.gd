class_name SettingsToggleData
extends Resource

# ==============================================================================
# SettingsToggleData — shared settings leaf (fox/components/settings).
#
# Mutualised from the two games that hand-rolled a byte-identical copy under
# their own src/popups/settings/data/. fox is a shared symlink, so a `class_name`
# leaf here exists in every consuming game — any local copy of the same
# class_name would collide. This is the SUPERSET of both games: the extra
# `icon_off` / `icon_tint` fields carry no cost for a game that leaves them unset.
#
# The top-level SettingsData (per-game layout) stays LOCAL; only the leaves are
# shared. Each game's settings-data.tres points its `path=` at this file while
# keeping the shared `uid=` (uid://by2vid442yluf).
# ==============================================================================

@export var id: String = ''
@export var label_key: String = ''
# Literal fallback when the project ships no translation for `label_key`
# (a starter game with no translations CSV would otherwise show the raw key).
@export var label_text: String = ''
@export var icon: Texture2D
# Optional icon shown when the toggle is Off (e.g. muted speaker / crossed note).
# Falls back to `icon` when unset, so single-state toggles keep one glyph.
@export var icon_off: Texture2D
# Optional icon tint override (e.g. orange for a rush flame). Transparent = use
# the row's default colour.
@export var icon_tint: Color = Color(0, 0, 0, 0)
@export var default_value: bool = false
