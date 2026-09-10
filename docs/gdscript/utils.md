# Utility libs

Small static helper classes you can call from anywhere. They expose only static
functions (no autoload needed), except `Generate` which loads a project asset
and `MenuNavigator` which you instantiate per menu.

- [`__` — Underscore](#underscore--__) — safe object access, colors, BBCode
- [`Wait` — timers](#wait) — await delays without boilerplate
- [`TimeTools` — dates](#timetools) — date formatting and countdowns
- [`Bundle` — bundle settings](#bundle) — read store/bundle metadata
- [`Generate` — random ids/names](#generate) — uids and player names
- [`HoloDrawUtils` — holographic draw](#holodrawutils) — letter-spacing and glass panels
- [`MenuNavigator` — menu focus](#menunavigator) — keyboard/gamepad cursor for menus
- [`ConfigStore` — config resources](#configstore) — CRUD over a folder of `.tres`

## Underscore (`__`)

Inspired by [Underscore.js](https://underscorejs.org/). Safe access to nested
data without crashing on `null`.

### `__.Get(path, obj)`

Reads a dotted path from a `Dictionary` or `Object`, returning `null` if any
segment is missing:

```gdscript
var record = __.Get('newRecord', body)        # body.newRecord
var x = __.Get('player.position.x', state)     # nested
```

### `__.GetOr(defaultValue, path, obj)`

Same, with a fallback when the result is `null`:

```gdscript
var delay = __.GetOr(0, 'delay', options)
```

### `__.Set(value, path, obj)`

Writes a (possibly nested) dotted path into a `Dictionary` or `Object`:

```gdscript
__.Set(100, 'score', state)
__.Set(true, 'flags.muted', state)
```

### `__.useColor(colorHex)`

Builds a `Color` from a hex string (`#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`):

```gdscript
var c = __.useColor('#A1553E')
```

### `__.bbcodeToANSI(bbcode)`

Converts Godot BBCode tags to terminal ANSI escape codes. This is what powers
the colored output of `G.log` — you rarely call it directly.

## Wait

Timer helpers to `await` delays without wiring a `Timer` by hand.

### `Wait.forSomeTime(parent, timeInSec)`

Creates a one-shot `Timer` as a child of `parent` and returns it, so you can
await its `timeout`:

```gdscript
await Wait.forSomeTime(self, 2).timeout
```

A delay of `0` returns `{timeout = true}` so awaiting still resolves
immediately.

### `Wait.withTimer(timeToWait, object, onTimeout)`

A **debounced** timer: re-calling it restarts the same timer instead of stacking
new ones (useful for "do X once the user stops doing Y"). The `object` must own a
`params` Dictionary where the timer is cached:

```gdscript
var params = {}   # the object must expose this

func onTyping():
  Wait.withTimer(0.5, self, func(): G.log('stopped typing'))
```

## TimeTools

Date/time helpers built on UTC. Datetime arguments are Godot datetime
dictionaries (`Time.get_datetime_dict_from_unix_time(...)`).

- `TimeTools.dateTimeToYYYYMMDDNumber(datetime)` → e.g. `20240820`
- `TimeTools.dateTimeToYYYYMMNumber(datetime)` → e.g. `202408`
- `TimeTools.dateTimeToReadableDate(datetime)` → e.g. `2024-03-13 10:29`
- `TimeTools.getDeviceTodayNumUTC()` → today as a `yyyymmdd` number
- `TimeTools.getTimeRemainingForToday()` → `"HH:MM:SS"` until midnight
- `TimeTools.getTimeRemainingForSeason()` → `{nbDays, timeBeforeMidnight}` until
  the 1st of next month
- `TimeTools.getTimeRemainingForThisWeek()` → `{nbDays, timeBeforeMidnight}`
  until next Monday
- `TimeTools.nbDaysInMonth(month, year)` → days in a month (leap-year aware)

```gdscript
var today = TimeTools.getDeviceTodayNumUTC()        # 20240820
var countdown = TimeTools.getTimeRemainingForToday() # "08:14:52"
```

## Bundle

Reads bundle/store metadata from `project.godot` `[bundle]` settings and from
`fox.config.json` (`bundles` section). Useful for "rate this app" / store links.

- `Bundle.getTitle()` → `bundle/title`
- `Bundle.getSubtitle()` → `bundle/subtitle`
- `Bundle.getPlatform()` → `bundle/platform`
- `Bundle.getAppId()` → iOS app id of the current bundle
- `Bundle.getStoreUrl()` → store URL of the current bundle for the current
  platform

```gdscript
if Bundle.getPlatform() == 'iOS':
  OS.shell_open('itms-apps://itunes.apple.com/app/' + Bundle.getAppId())
else:
  OS.shell_open(Bundle.getStoreUrl())
```

## Generate

Generates random ids and player names. Names are drawn from
`res://assets/name-elements.json` (a `{adjectives: [...], names: [...]}`
file you provide), so add it as an `Autoload` (e.g. `Generate`) since it loads
a project asset:

```ini
[autoload]

Generate="*res://fox/autoloads/generate.gd"
```

- `Generate.uid(prefix)` → a unique id, e.g. `player-1718000000-12345-678901`
  (pass `''` or `null` for no prefix)
- `Generate.name()` → a random `AdjectiveName` (falls back to `'Player'` if the
  asset is missing)

```gdscript
var id = Generate.uid('player')
var nick = Generate.name()        # "FieryFox"
```

## HoloDrawUtils

Holographic 2D draw helpers for custom `_draw()` code, at
`res://fox/libs/holo-draw-utils.gd`. Static only, no autoload.

### `HoloDrawUtils.draw_spaced(canvas, font, pos, text, font_size, color, spacing)`

Draws a string with manual letter-spacing, glyph by glyph. `Label` has no
letter-spacing property, so this is how the games get their wide holographic
caps. Spacing is inserted only *between* glyphs, never after the last one:

```gdscript
func _draw():
  HoloDrawUtils.draw_spaced(self, font, Vector2(0, -8), label_text, font_size, color, 3.0)
```

### `HoloDrawUtils.get_spaced_width(font, text, font_size, spacing) -> float`

Measures what `draw_spaced` will occupy, with the same spacing rule, so a run
can be centered or right-aligned before drawing it:

```gdscript
var w = HoloDrawUtils.get_spaced_width(font, label_text, font_size, spacing)
HoloDrawUtils.draw_spaced(self, font, Vector2(-w / 2.0, font_size * 0.35), label_text, font_size, color, spacing)
```

### `HoloDrawUtils.draw_panel(canvas, rect, color, bright_width = 1.5)`

Draws a framed glass panel: a fill, an outer glow border and a bright inner
border.

> This helper reads the **consuming game's** `DesignTokens` by `class_name`
> (`DesignTokens.Backgrounds.PANEL`, `DesignTokens.Glow.PANEL_BORDER_GLOW`,
> `DesignTokens.Glow.PANEL_BORDER_BRIGHT`). Fox declares no such class, so
> `draw_panel` only resolves in a game that defines those tokens:

```gdscript
func _draw():
  HoloDrawUtils.draw_panel(self, Rect2(Vector2.ZERO, panel_size), accent_color)
```

## MenuNavigator

Shared keyboard / gamepad focus cursor for menus, at
`res://fox/libs/menu-navigator.gd`. Unlike the other libs here it is a
`RefCounted` you instantiate per menu: `MenuNavigator.new()`.

It walks a ragged grid of focusable items, keeps a `(row, col)` cursor,
highlights the focused item, plays a tick and confirms on a tap. It reads no
input on its own: directions are the fox `Controls.DIR_*` contract and the host
injects its own signals through `attach`.

### Content

- `set_rows(rows)`: a ragged grid, an `Array` of rows, each row an `Array` of items
- `set_grid(items, columns)`: a rectangular grid built row-major from a flat list
- `set_row(items)`: a single horizontal row (LEFT/RIGHT walk it, UP/DOWN inert)
- `set_column(items)`: a single vertical column (UP/DOWN walk it, LEFT/RIGHT inert)
- `clear()`: drop the content and reset the cursor

### Policy and callbacks

- `set_wrap(horizontal, vertical)`: per-axis, `false` clamps at the edges, `true` wraps
- `set_highlight(callback)`: `func(item, focused: bool) -> void`, no-op until set
- `set_sound(callback)`: `func() -> void`, played on a genuine focus change
- `set_confirm(callback)`: `func() -> void`, run on the tap signal
- `set_direction_interceptor(callback)`: `func(direction: int) -> bool`, first shot
  at every direction, return `true` to consume it and skip the built-in move

### Lifecycle

`attach(direction_signal, tapped_signal = Signal(), connect_confirm = true)`
connects the host signals (idempotent), `detach()` disconnects the very same
ones:

```gdscript
_nav = MenuNavigator.new()
_nav.set_row(_cards)
_nav.set_wrap(false, false)
_nav.set_highlight(_highlight_card)
_nav.set_direction_interceptor(_intercept_direction)
_nav.set_confirm(_confirm_focus)
_nav.focus_changed.connect(_on_nav_focus_changed)
_nav.seed(0, _focus_index)
_nav.attach(EventListener.direction_hold_started, EventListener.tapped)
```

### Focus

- `seed(row = 0, col = 0)`: silent initial seed, lights the first cell without a tick
- `set_focus(row, col, silent = false, force = false)`: `force` re-applies the
  highlight even when the cursor already points there (two navigators sharing one
  highlight layer)
- `set_focus_flat(index, silent = false)`: same, by row-major index
- `focus_item(item, silent = true)`: mirror a mouse hover onto the cursor
- `navigate(direction)`: run the interceptor, then the built-in move
- `move_horizontal(delta)` / `move_vertical(delta)`: bypass the interceptor, for a
  host-owned hold-repeat that already resolved the direction

Accessors: `focus_row()`, `focus_col()`, `focus_flat_index()` (`-1` when there is
no focus), `current_item()`, `is_empty()`, `count()`.

The `focus_changed(row, col)` signal fires on every applied focus change, which
is where a screen runs its own layout (a coverflow slide, a header label).

## ConfigStore

Generic CRUD over a folder of slugified `.tres` resources, at
`res://fox/libs/config-store.gd`. Static only, and agnostic of any concrete
resource class: a game pins a directory and a fallback slug, then delegates.

The id of a config **is** its file basename, so `path_for(dir, id)` is always
`dir + id + ".tres"`. Ids come from slugifying a `display_name` (lowercase,
non-alphanumeric to dashes, collapsed and trimmed), with a `-2` / `-3` suffix on
collision and `fallback_slug` when the name slugifies to empty.

- `ConfigStore.list_ids(dir)` → sorted ids, creating `dir` when missing
- `ConfigStore.list_entries(dir)` → `[{id, name}]`, `name` read from the
  resource's `display_name` when it exposes one, else the id
- `ConfigStore.path_for(dir, id)` → the `.tres` path
- `ConfigStore.load_config(dir, id)` → the `Resource`, or `null` when missing
- `ConfigStore.save_config(dir, config, id = "")` → `Error` (an empty `id` is read
  back from the config's own `resource_path`)
- `ConfigStore.create(dir, config, fallback_slug)` → the config, bound to a unique
  slug and saved (the caller instantiates the concrete resource)
- `ConfigStore.duplicate_config(dir, id, new_name, fallback_slug, on_copy = Callable())`
  → a deep copy under a new unique slug, `on_copy` running the game-specific init
- `ConfigStore.rename(dir, id, new_name, fallback_slug)` → the resulting id (`""` on
  failure), moving the `.tres` when the new name yields another slug
- `ConfigStore.delete(dir, id)` → `Error`

Configs persist in `res://` (project data), never `user://`, and re-scanning the
editor filesystem after a create or a delete is the caller's job. A game store is
then a thin façade:

```gdscript
@tool
class_name BiomeStore
extends RefCounted

const DIR := 'res://src/world/biome/biomes/'
const FALLBACK_SLUG := 'biome'

static func list_entries() -> Array:
  return ConfigStore.list_entries(DIR)

static func create(display_name: String) -> BiomeConfig:
  var config := BiomeConfig.new()
  config.display_name = display_name
  return ConfigStore.create(DIR, config, FALLBACK_SLUG) as BiomeConfig
```
