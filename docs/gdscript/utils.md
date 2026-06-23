# Utility libs

Small static helper classes you can call from anywhere. They expose only static
functions (no autoload needed), except `Generate` which loads a project asset.

- [`__` — Underscore](#underscore--__) — safe object access, colors, BBCode
- [`Wait` — timers](#wait) — await delays without boilerplate
- [`TimeTools` — dates](#timetools) — date formatting and countdowns
- [`Bundle` — bundle settings](#bundle) — read store/bundle metadata
- [`Generate` — random ids/names](#generate) — uids and player names

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

Generate="*res://fox/libs/generate.gd"
```

- `Generate.uid(prefix)` → a unique id, e.g. `player-1718000000-12345-678901`
  (pass `''` or `null` for no prefix)
- `Generate.name()` → a random `AdjectiveName` (falls back to `'Player'` if the
  asset is missing)

```gdscript
var id = Generate.uid('player')
var nick = Generate.name()        # "FieryFox"
```
