# Steam

The `Steam` core feature wraps the [GodotSteam](https://godotsteam.com)
GDExtension: it initializes Steam at startup, pumps its callbacks every frame,
shuts it down cleanly, detects the Steam Deck, and exposes achievements, the
Deck floating keyboard and the store overlay.

Every method degrades to a safe no-op when Steam is not there, so the same code
runs in the editor, in a headless test, in a build launched outside Steam and in
an export shipped to another store.

## Setup

The base is extended **by path**, like `sound.gd` or `router.gd`: it carries no
`class_name`. Create `src/core/steam.gd` in your game:

```gdscript
extends 'res://fox/core/steam.gd'
```

Add it as an `Autoload` named `SteamManager`. Nothing else is required: the base
initializes itself in `_ready()` and tears itself down in `_exit_tree()`.

### The subclass contract

Three rules, and they are the whole contract:

- override `_on_initialized()` to wire your game-specific work. It is called
  once, and only after a successful `steamInitEx()`, so everything inside it can
  assume a live Steam session,
- if you override `_ready()`, call `super._ready()` first, otherwise Steam is
  never initialized,
- if you override `_exit_tree()`, call `super._exit_tree()`, otherwise the
  shutdown never runs.

```gdscript
extends 'res://fox/core/steam.gd'

func _on_initialized() -> void:
  # a live Steam session is guaranteed here
  prints('[Game] steam ready for', username)
```

### The headless guard

A headless run (`--headless`: tests, tools, CI, asset import) is never a real
Steam launch. `steamInitEx()` would always fail there, and the failure is
printed by the native SDK itself on stdout (`[S_API FAIL] SteamAPI_Init()
failed...`), which no Godot-side log filter can suppress: it would pollute every
headless report. So the base does not even attempt Steam without a display:

```gdscript
if DisplayServer.get_name() == 'headless':
  on_steam_deck = _detect_steam_deck_hardware()
  return
```

Two more guards follow it: `Engine.has_singleton('Steam')` (the extension may
simply be absent, for instance in a web export) and the `steamInitEx()` status
itself. In all three cases `initialized` stays `false` and the Deck detection
still runs from the environment.

The singleton is never named by its bare `Steam` global identifier either: it is
resolved dynamically into `_steam`, which keeps the base parsable in every
context, including when it is loaded through the symlinked `res://fox/` path.

## State

```gdscript
SteamManager.initialized     # bool: a live Steam session
SteamManager.steam_id        # int
SteamManager.username        # String, the persona name
SteamManager.is_steam_deck() # bool
SteamManager.get_app_build_id()
```

`is_steam_deck()` answers `true` when Steam reports the hardware **or** when
SteamOS exports `SteamDeck=1` in the environment, so a Deck is recognized even
when the extension failed to init or the binary was launched outside Steam. The
value is queried once at init and cached, because `FoxResponsive` reads it
often.

`get_app_build_id()` returns the SteamPipe build id of the installed build, or
`0` without Steam. It tells two builds apart when they share the same version
(a re-publish without a version bump).

## Achievements

```gdscript
SteamManager.are_achievements_available() -> bool
SteamManager.unlock_achievement(api_name: String) -> bool
SteamManager.unlock_achievements(api_names: Array) -> int
```

`unlock_achievement()` flips one achievement and returns whether Steam accepted
it. `unlock_achievements()` flips a whole batch and returns how many names were
accepted:

```gdscript
SteamManager.unlock_achievement('FIRST_RUN')
SteamManager.unlock_achievements(['FIRST_RUN', 'ALL_LEVELS', 'NO_DAMAGE'])
```

Both are a silent no-op without Steam, so a caller never has to ask whether
Steam is there. Nothing is decided here: the game owns which achievement is
earned and when, this is only the relay.

### The deferred store flush

`setAchievement()` is called once per name, then `storeStats()` is called
**once** for the whole batch. This matters on a boot path: a save completed
before the achievements existed can grant dozens of names in a single pass, and
`storeStats()` is a client round-trip, so one call per name would hammer it for
nothing.

When a `storeStats()` fails, the base remembers it (`_achievements_store_pending`)
and flushes again on the next batch, even one that accepted no new name. The set
achievements live in the Steam client meanwhile, so a lost flush costs a delay,
never an achievement: but only if someone asks again.

Stats are never requested first: Valve deprecated `RequestCurrentStats` for the
running user, and the client already holds the current user stats when
`steamInitEx()` returns.

## The floating keyboard

The Steam floating gamepad keyboard is the one a player gets on a Steam Deck. It
exists only in a real Steam session, and only if the GodotSteam build in use
exposes it, which is why availability is asked rather than assumed:

```gdscript
SteamManager.has_floating_keyboard() -> bool
SteamManager.show_floating_keyboard(rect: Rect2) -> bool
SteamManager.dismiss_floating_keyboard() -> void
SteamManager.connect_floating_keyboard_dismissed(handler: Callable) -> void
```

`show_floating_keyboard()` raises it over `rect`, in screen coordinates, and
returns `false` when it could not be raised. That `false` is the caller cue to
fall back to the OS virtual keyboard:

```gdscript
func _on_field_focused(field: LineEdit) -> void:
  if SteamManager.show_floating_keyboard(field.get_global_rect()):
    return
  DisplayServer.virtual_keyboard_show(field.text)
```

`connect_floating_keyboard_dismissed()` relays the Steam-side signal saying the
player closed the keyboard from the overlay. A game usually treats it exactly
like a tap outside the field. Connecting is a no-op without Steam, so it can be
wired unconditionally:

```gdscript
func _on_initialized() -> void:
  SteamManager.connect_floating_keyboard_dismissed(_on_keyboard_dismissed)
```

## The store page

```gdscript
SteamManager.get_store_app_id() -> int
SteamManager.open_store_page() -> bool
```

`open_store_page()` shows the game store page in the Steam overlay. It returns
`false` when the overlay is not there, which is the caller cue to open a browser
instead:

```gdscript
if not SteamManager.open_store_page():
  OS.shell_open(STORE_URL)
```

The app id is resolved **at runtime**, through `get_store_app_id()`, which
returns the id the process actually initialized against (`getAppID()`). The base
ships no app id literal of its own: a shared, public base has no business
carrying the numbers of one game.

A game whose store link must point somewhere else overrides that one method. The
typical case is a build shipping as a separate demo app whose purchase
call-to-action has to open the full game:

```gdscript
extends 'res://fox/core/steam.gd'

# the store link always points at the full game, even from the demo build
func get_store_app_id() -> int:
  return FULL_GAME_APP_ID
```

`open_store_page()` returns `false` when the resolved id is `0` or below, so a
missing or unusable id degrades exactly like a missing overlay instead of
calling into the SDK with a meaningless value.

## What the base deliberately leaves out

**The UGC / Workshop layer is not in Fox, and stays in the game.** Publishing a
Workshop item is not a wrapper, it is a workflow: a staging folder, tags the app
declares, a legal agreement the player must accept, queries, votes, playtime
tracking, subscribed items to install and rescan. All of it is shaped by what
the game publishes, so a generic version would either be an empty pass-through
or a set of decisions imposed on every game that never asked for them.

A game that needs the Workshop adds those wrappers in its own
`src/core/steam.gd` subclass, next to `_on_initialized()`, where the game
already speaks Steam. The base gives it `initialized`, `_steam` and the callback
pump it needs, and stays out of the way.

## Shutting down

```gdscript
SteamManager.shutdown()
```

`shutdown()` is idempotent and guarded by `initialized`, so calling it and then
letting `_exit_tree()` run is safe. Call it explicitly from a live frame, just
before `get_tree().quit()`, rather than relying on `_exit_tree()` alone: when
the Steam overlay is hooked (the game was launched through Steam), running
`steamShutdown()` during the `SceneTree` destruction deadlocks the overlay and
the process survives the window close. Shutting down first, while the main loop
is still pumping, avoids it.
