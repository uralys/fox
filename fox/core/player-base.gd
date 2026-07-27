extends Node

# ==============================================================================
# PlayerBase — generic player-state persistence (fox core).
#
# Extended by path (like sound.gd / router.gd, NO class_name): each game points
# its `Player` autoload at `res://fox/core/player-base.gd` and overrides the two
# hooks for its own save schema. The shared trunk captured here — the 2nd
# occurrence of the same skeleton across games, so DRY threshold reached — is:
#
#   * a `state` Dictionary held in memory,
#   * load / save via FileAccess.store_var / get_var on G.RECORD_PATH,
#   * an anonymous 16-char device id seeded on first launch,
#   * generic audio option accessors (musicOn / soundsOn).
#
# Hooks (virtual — override per game):
#
#   _default_state() -> Dictionary
#     Initial state for a genuine first launch, BEFORE the deviceId is seeded.
#     The game returns its full schema here (options, progression, …). The base
#     default only carries deviceId + the audio flags. load_saved_data() sets
#     `state.deviceId` on top of whatever this returns.
#
#   _run_migrations(loaded) -> Dictionary
#     Receives the Dictionary read back from disk and returns the migrated
#     state. No-op passthrough by default. Implementations may mutate `loaded`
#     in place and return it, or return a fresh Dictionary. The base assigns the
#     result to `state`; persisting a migration is the game's responsibility
#     (call save() from within the hook when it changed something).
#
# Backups extension point: this base is deliberately single-file (one .bin, no
# rotation). Games that want backup rotation (fox Files.rotateBackups /
# restoreVar) override save() / load_saved_data() to wrap the write and the
# restore fallback — see faraday-corridors src/core/player.gd.
# ==============================================================================

var state = {}

# ------------------------------------------------------------------------------
# Persistence
# ------------------------------------------------------------------------------

func load_saved_data() -> void:
	var path = G.RECORD_PATH

	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file != null:
			var content = file.get_var()
			file.close()
			if content is Dictionary and not content.is_empty():
				state = _run_migrations(content)
				return

	state = _default_state()
	state.deviceId = _generate_device_id()
	save()

func save() -> void:
	var file = FileAccess.open(G.RECORD_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_var(state)
	file.close()

# ------------------------------------------------------------------------------
# Generic option accessors (shared audio trunk)
# ------------------------------------------------------------------------------

func is_music_on() -> bool:
	return __.GetOr(true, 'options.musicOn', state)

func is_sounds_on() -> bool:
	return __.GetOr(true, 'options.soundsOn', state)

# ------------------------------------------------------------------------------
# Hooks (virtual — overridden per game)
# ------------------------------------------------------------------------------

func _default_state() -> Dictionary:
	return {
		"deviceId": "",
		"options": {
			"musicOn": true,
			"soundsOn": true
		}
	}

func _run_migrations(loaded: Dictionary) -> Dictionary:
	return loaded

# ------------------------------------------------------------------------------
# Device id
# ------------------------------------------------------------------------------

func _generate_device_id() -> String:
	var chars = "abcdefghijklmnopqrstuvwxyz0123456789"
	var id = ""
	for i in range(16):
		id += chars[randi() % chars.length()]
	return id
