extends Node

# ==============================================================================
# Steam — generic base autoload wrapping the GodotSteam GDExtension (which
# exposes `Steam` globally). Extended by path (no class_name, like sound/router):
# each game ships its own `res://src/core/steam.gd` that `extends` this file and
# adds its own game-specific features on top.
#
# Responsibilities kept generic here:
#  - init at startup, guarded on Engine.has_singleton('Steam') and on having a
#    display, so the editor, headless runs and non-Steam launches run cleanly
#    (every method degrades to a safe no-op),
#  - pump callbacks each frame (_process),
#  - idempotent teardown (shutdown), safe to call twice,
#  - Steam Deck detection (Steam-reported OR SteamOS env var), cached once,
#  - installed SteamPipe build id,
#  - achievements, unlocked one by one or in a batch flushed once,
#  - the Steam Deck floating gamepad keyboard,
#  - the store page overlay.
#
# The store page targets the app the process INITIALIZED against
# (`Steam.getAppID()`), never a hardcoded app id: the base ships no literal, and
# a game whose store link must point somewhere else (a demo build whose purchase
# call-to-action points at the full game) overrides `get_store_app_id()`.
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
	# A headless run (--headless: tests, tools, CI, asset import) is never a real
	# Steam launch. Calling steamInitEx() there always fails, and the failure is
	# printed by the native SDK itself on stdout ("[S_API FAIL] SteamAPI_Init()
	# failed…"), which no Godot-side log filter can suppress — it pollutes every
	# headless test report. So Steam is not even attempted without a display.
	if DisplayServer.get_name() == 'headless':
		on_steam_deck = _detect_steam_deck_hardware()
		return

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

# ------------------------------------------------------------------------------
# Achievements
#
# A thin relay: nothing is decided here, the game owns which achievement is
# earned and when. Stats are never requested first: Valve deprecated
# RequestCurrentStats for the running user, and the client already holds the
# current user stats when steamInitEx() returns.
# ------------------------------------------------------------------------------

# A storeStats() that failed is retried on the next batch. Set achievements live
# in the client until a flush succeeds, so a lost flush costs a delay, never an
# achievement: but only if someone asks again.
var _achievements_store_pending: bool = false

# True when an unlock can even be attempted. False in the editor, in a headless
# run, and in a build launched outside Steam.
func are_achievements_available() -> bool:
	return initialized

# Flip one achievement and flush. A silent no-op without Steam.
func unlock_achievement(api_name: String) -> bool:
	return unlock_achievements([api_name]) > 0

# Flip a whole batch and flush ONCE. This is the form a boot path needs: a save
# completed before the achievements existed grants dozens of names in a single
# pass, and storeStats() is a client round-trip, so one call per name would
# hammer it for nothing. Returns how many names Steam accepted.
func unlock_achievements(api_names: Array) -> int:
	if not initialized or api_names.is_empty():
		return 0

	var accepted: int = 0
	for entry in api_names:
		var api_name := String(entry)
		if api_name.is_empty():
			continue
		if _steam.setAchievement(api_name):
			accepted += 1
		else:
			push_warning('[SteamManager] setAchievement refused ' + api_name)

	if accepted == 0 and not _achievements_store_pending:
		return 0

	_achievements_store_pending = not _steam.storeStats()
	if _achievements_store_pending:
		push_warning('[SteamManager] storeStats failed: %d achievement(s) held by the client' % accepted)
	else:
		prints('[SteamManager] achievements stored:', accepted)
	return accepted

# ------------------------------------------------------------------------------
# Overlay surfaces: the two places a game asks Steam to draw something over it.
# Same contract as every wrapper here, a clean no-op without Steam, and the
# caller keeps its own fallback (the browser for the store, the OS keyboard for
# text entry). They exist so that no screen has to name the SDK.
# ------------------------------------------------------------------------------

# The app id the store overlay opens on. Defaults to the app this process
# initialized against, which is what a single-app game wants. A game shipping a
# separate demo app overrides this to keep its purchase call-to-action pointing
# at the full game.
func get_store_app_id() -> int:
	if not initialized:
		return 0
	return int(_steam.getAppID())

# Show the game store page in the Steam overlay. False when the overlay is not
# there, which is the caller cue to open a browser instead.
func open_store_page() -> bool:
	if not initialized:
		return false
	var app_id := get_store_app_id()
	if app_id <= 0:
		return false
	_steam.activateGameOverlayToStore(app_id)
	return true

# The Steam floating gamepad keyboard (the Deck one). Available only in a real
# Steam session, and only if this GodotSteam build exposes it.
func has_floating_keyboard() -> bool:
	return initialized and _steam.has_method('showFloatingGamepadTextInput')

# Raise it over `rect` (screen coordinates). False when it could not be raised,
# so the caller falls back to the OS virtual keyboard.
func show_floating_keyboard(rect: Rect2) -> bool:
	if not has_floating_keyboard():
		return false
	_steam.showFloatingGamepadTextInput(0, int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y))
	return true

func dismiss_floating_keyboard() -> void:
	if not initialized or not _steam.has_method('dismissFloatingGamepadTextInput'):
		return
	_steam.dismissFloatingGamepadTextInput()

# Relay of the Steam-side signal saying the player closed the keyboard from the
# overlay: a game treats it exactly like a tap outside the field. Connecting is
# a no-op without Steam, so the caller never has to ask whether Steam is there.
func connect_floating_keyboard_dismissed(handler: Callable) -> void:
	if not initialized or not _steam.has_signal('floating_gamepad_text_input_dismissed'):
		return
	_steam.floating_gamepad_text_input_dismissed.connect(handler)
