extends Node

# ==============================================================================
# Steam — generic base autoload wrapping the GodotSteam GDExtension (which
# exposes `Steam` globally). Extended by path (no class_name, like sound/router):
# each game ships its own `res://src/core/steam.gd` that `extends` this file and
# adds its own game-specific features on top.
#
# Responsibilities kept generic here:
#  - init at startup, guarded on Engine.has_singleton('Steam') so the editor and
#    non-Steam launches run cleanly (every method degrades to a safe no-op),
#  - pump callbacks each frame (_process),
#  - idempotent teardown (shutdown), safe to call twice,
#  - Steam Deck detection (Steam-reported OR SteamOS env var), cached once,
#  - installed SteamPipe build id.
#
# Subclasses hook post-init work by overriding `_on_initialized()` (called once,
# only after a successful steamInitEx). They must call `super._exit_tree()` if
# they override _exit_tree, and `super._ready()` if they override _ready.
# ==============================================================================

var initialized: bool = false
var steam_id: int = 0
var username: String = ''
# Steam-reported hardware: true only on an actual Steam Deck. Fixed for the whole
# session, so it is queried once at init and cached (Responsive reads it often).
var on_steam_deck: bool = false

# The GodotSteam GDExtension singleton, resolved dynamically (never referenced by
# its bare `Steam` global identifier). This keeps the base compilable in every
# context — headless import, non-Steam builds, editor tooling, and crucially when
# this file is loaded as an autoload base through the symlinked `res://fox/` path,
# where the `Steam` global is not injected into the parse scope. Null when the
# extension is absent; every call site is guarded by `initialized`.
var _steam: Object = null

# ------------------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------------------

func _ready() -> void:
	if not Engine.has_singleton('Steam'):
		push_warning('[SteamManager] GodotSteam GDExtension not loaded — running without Steam')
		on_steam_deck = _detect_steam_deck_hardware()
		return
	_steam = Engine.get_singleton('Steam')

	var result = _steam.steamInitEx()
	if result.status != 0:
		push_warning('[SteamManager] steamInit failed: status=%s — %s' % [result.status, result.verbal])
		on_steam_deck = _detect_steam_deck_hardware()
		return

	initialized = true
	steam_id = _steam.getSteamID()
	username = _steam.getPersonaName()
	on_steam_deck = _steam.isSteamRunningOnSteamDeck() or _detect_steam_deck_hardware()
	prints('[SteamManager] init OK — user=', username, 'steam_id=', steam_id, 'steam_deck=', on_steam_deck)

	_on_initialized()

func _process(_delta) -> void:
	if initialized:
		_steam.run_callbacks()

# Idempotent Steam teardown. Must be called from a live frame (e.g. just before
# get_tree().quit()), NOT only relied upon via _exit_tree: when the Steam overlay
# is hooked (game launched through Steam), running steamShutdown() during the
# SceneTree destruction deadlocks the overlay and the process survives the window
# close. Shutting down first, while the main loop is still pumping, avoids it.
# Guarded by `initialized` so a second call (shutdown() then _exit_tree()) no-ops.
func shutdown() -> void:
	if not initialized:
		return
	initialized = false
	_steam.steamShutdown()

func _exit_tree() -> void:
	shutdown()

# ------------------------------------------------------------------------------
# Hooks
# ------------------------------------------------------------------------------

# Called once after a successful steamInitEx. Override in a subclass to wire
# game-specific callbacks (signals, extra services, …). No-op by default.
func _on_initialized() -> void:
	pass

# ------------------------------------------------------------------------------
# Queries
# ------------------------------------------------------------------------------

# Hardware detection independent of the Steam SDK: SteamOS always exports
# `SteamDeck=1` in the game's environment (gamescope/Steam runtime), so the deck
# is recognized even when the GodotSteam GDExtension failed to init or the binary
# was launched outside Steam. Cached once at init.
func _detect_steam_deck_hardware() -> bool:
	return OS.get_environment('SteamDeck') == '1'

# True when running on an actual Steam Deck (Steam-reported or SteamOS env var).
# False otherwise, so callers safely fall back to their own heuristics.
func is_steam_deck() -> bool:
	return on_steam_deck

# SteamPipe build id of the currently installed build, or 0 when Steam is
# unavailable (editor, launched outside Steam). Distinguishes two builds that
# share the same version (re-publish without a version bump).
func get_app_build_id() -> int:
	if not initialized:
		return 0
	return _steam.getAppBuildId()
