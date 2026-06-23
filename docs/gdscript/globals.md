# Globals (G) & Debug (DEBUG)

Fox ships two core autoloads you use everywhere: `G` (globals + logging) and
`DEBUG` (debug flags that auto-disable in release).

## G — globals

Add it as an `Autoload` named `G`:

```ini
[autoload]

G="*res://fox/core/globals.gd"
```

On startup `G` reads your `[bundle]` settings from `project.godot` and exposes
them as fields.

### Bundle fields

- `G.BUNDLE_ID` — `bundle/id`
- `G.ENV` — `bundle/env` (`'debug'` or `'release'`)
- `G.PLATFORM` — `bundle/platform`
- `G.VERSION` — `bundle/version`
- `G.VERSION_CODE` — `bundle/versionCode`
- `G.RECORD_PATH` — save file path, `user://saved-data.<bundleId>.bin`
- `G.RELEASE` / `G.DEBUG` — the `'release'` / `'debug'` string constants

### Screen fields

These are filled by `app.gd` once the screen reference exists, and refreshed on
every window resize:

- `G.W` — screen width
- `G.H` — screen height
- `G.SCREEN_CENTER` — `Vector2(W/2, H/2)`

Safe getters that fall back to the live viewport if the fields are not set yet:

- `G.screenSize() -> Vector2`
- `G.screenCenter() -> Vector2`

### Logging

`G.log(...)` prints up to 8 arguments. String arguments are parsed as
[BBCode](https://docs.godotengine.org/en/stable/tutorials/ui/bbcode_in_richtextlabel.html)
and rendered with ANSI colors in the terminal, so you can color your logs:

```gdscript
G.log('✅ [b][color=green]score posted[/color][/b]', {newRecord = true})
```

`G.debug(...)` is the same, prefixed with a magenta `(debug)` tag, and is a
no-op when `G.ENV == 'release'` — use it for noisy development logs that must
never reach production.

## DEBUG — debug flags

Add it as an `Autoload` named `DEBUG`:

```ini
[autoload]

DEBUG="*res://fox/core/debug.gd"
```

Extend it from your own script to declare flags inside an `options` dictionary:

```gdscript
extends 'res://fox/core/debug.gd'

var NO_INTRO_ANIMATION = true
var SOUND_OFF = false

var options = {
  NO_INTRO_ANIMATION = NO_INTRO_ANIMATION,
  SOUND_OFF = SOUND_OFF,
}
```

`DEBUG.setup()` is called by `app.gd` at boot. Its contract:

- in `release`, **every** option is forced to `false` (debug code can never
  ship enabled);
- in `debug`, it logs which options are active so you always know what is on.

Read the flags anywhere, e.g. `if DEBUG.SOUND_OFF: return`. Fox itself reads
`DEBUG.NO_INTRO_ANIMATION` (skip the intro) and `DEBUG.SOUND_OFF` (mute).
