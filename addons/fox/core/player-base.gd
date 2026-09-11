extends Node

# ==============================================================================
# PlayerBase — generic player-state persistence (fox core).
#
# Extended by path (like sound.gd / router.gd, NO class_name): each game points
# its `Player` autoload at `res://addons/fox/core/player-base.gd` and overrides the two
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
#   _record_path() -> String
#     Absolute path of the save file, G.RECORD_PATH by default. Override this
#     one hook to redirect the save (a throwaway file for a test run, a
#     per-profile path): load_saved_data() and save() both take the path from
#     here, so no game has to re-implement either of them just to move the file.
#
# No-clobber contract: reads go through Files.readVarSafe(), which separates a
# missing file (a genuine first launch) from an unreadable one (locked by
# another process, truncated by a crash, or mid cloud sync). A first launch
# seeds the defaults and persists them; an unreadable file NEVER does. It falls
# back to Files.restoreLatestBackup(), and when no backup answers it runs on
# defaults in memory WITHOUT writing, so a transient lock or an in-flight cloud
# file stays recoverable instead of being overwritten by an empty state.
#
# Backups: save() rotates the live file through Files.rotateBackups() before
# overwriting it, so a last-writer-wins cloud overwrite stays recoverable. The
# rotation is throttled inside fox, so frequent saves never churn the backups,
# and it is skipped entirely while the live file is known corrupt.
# ==============================================================================

var state = {}

# Raised when the live save file exists but could not be read (locked, truncated,
# mid cloud sync). While it is up, save() must NOT rotate the unreadable live file
# into the backups: that would push corrupt bytes into backup-0 and shift the good
# snapshots out. Lowered by the next successful write, which replaces the bad file
# with a valid state.
var _live_file_corrupt := false

# ------------------------------------------------------------------------------
# Persistence
# ------------------------------------------------------------------------------

func load_saved_data() -> void:
	var path := _record_path()
	var read := Files.readVarSafe(path)

	if read.status == Files.READ_OK:
		state = _run_migrations(read.content)
		return

	# Nothing on disk: genuine first launch, seed the defaults and persist them.
	if read.status == Files.READ_ABSENT:
		state = _default_state()
		state.deviceId = _generate_device_id()
		save()
		return

	# The file is there but unusable. Treating it as a first launch would reset the
	# progression and immediately overwrite bytes that are still recoverable.
	G.log('[PlayerBase] live save unreadable, attempting backup restore')
	_live_file_corrupt = true

	var restored := Files.restoreLatestBackup(path)
	if restored.status == Files.READ_OK:
		state = _run_migrations(restored.content)
		# Writes the recovered state over the corrupt file (without rotating it into
		# the backups) and lowers the corrupt flag.
		save()
		return

	# Every backup exhausted: run on defaults in memory but do NOT save(), so a
	# transient lock or an in-flight cloud file is never clobbered. The corrupt flag
	# stays up, so the next legitimate write overwrites the bad file without
	# rotating it into the backups.
	G.log('[PlayerBase] no usable backup, loading defaults without persisting')
	state = _default_state()
	state.deviceId = _generate_device_id()

func save() -> void:
	var path := _record_path()

	if not _live_file_corrupt:
		Files.rotateBackups(path)

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		G.log('[PlayerBase] cannot open the save file for writing: ', path)
		return

	file.store_var(state)
	file.close()
	# The file now holds a valid state: resume normal rotation on the next saves.
	_live_file_corrupt = false

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

func _record_path() -> String:
	return G.RECORD_PATH

# ------------------------------------------------------------------------------
# Device id
# ------------------------------------------------------------------------------

func _generate_device_id() -> String:
	var chars = "abcdefghijklmnopqrstuvwxyz0123456789"
	var id = ""
	for i in range(16):
		id += chars[randi() % chars.length()]
	return id
