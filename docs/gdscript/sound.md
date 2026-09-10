# Sound

The `Sound` core feature plays one-shot SFX and looping music through pooled
`AudioStreamPlayer`s, with mute toggles and same-sample ducking built in.

## Setup

Create `src/core/sound.gd` extending the Fox core:

```gdscript
extends 'res://fox/core/sound.gd'

# map sound names to .ogg paths
var oggFiles = {
  onButtonPress = "res://assets/sounds/button.ogg",
  confirm = "res://assets/sounds/confirm.ogg",
}

# the ordered list of music tracks to cycle through
var MUSICS = [
  "res://assets/musics/track-1.ogg",
  "res://assets/musics/track-2.ogg",
]
```

Add it as an `Autoload` named `Sound`, then initialize it once (typically from
your app boot):

```gdscript
Sound.init()              # init(musicOn = true, soundsOn = true)
```

`init()` reads your `oggFiles`, sets the mute flags, and (re)creates a clean
audio host node — calling it again (e.g. after a data reset) frees the previous
players so nothing doubles up.

## Playing SFX

```gdscript
Sound.play('onButtonPress')        # by name (key of oggFiles)
Sound.play('confirm', 0.2)         # with a 0.2s delay
Sound.play('confirm', 0, 0.5)      # at half (linear) volume
```

`play()` does nothing when sounds are muted or when `DEBUG.SOUND_OFF` is set. It
returns the `AudioStreamPlayer` it started (or `null`), so a caller can keep a
handle on it.

### Volume

`play(name, delay, volume)` takes an optional **linear** `volume` (default
`1.0` = unchanged, converted to dB via `linear_to_db`). It is multiplied by the
per-sound scale returned by the `_sound_volume(name)` hook, so a game can expose
a volume table / channel mix by overriding that hook instead of re-wrapping
`play()`:

```gdscript
extends 'res://fox/core/sound.gd'

var SOUNDS_VOLUME := 0.8

# Applied to every SFX; the base multiplies it into the per-play volume.
func _sound_volume(_name):
  return SOUNDS_VOLUME
```

A combined scale of exactly `1.0` leaves the player untouched (`0 dB`); `0` or
below is floored to silence. Both the argument and the hook default to `1.0`, so
the base behaviour is unchanged when neither is used.

### Same-sample ducking

When the *same* sample retriggers rapidly, Fox fades the previous instance back
(`-8 dB`, kept audible underneath) and retires older ones, so tight bursts are
heard cleanly instead of piling up into a flood. This is automatic for `play()`.

## Audio channels

Every SFX can belong to a **channel** carrying its own on-flag and its own
linear volume, so a player may silence the interface ticks while keeping the
gameplay sounds, and level each group on its own. Music is not a channel: it
keeps its separate streamed path and its own `MUSIC_ON` flag.

Two channels ship with the base:

```gdscript
Sound.CHANNEL_INTERFACE   # 'interface'      : UI feedback (select, switch)
Sound.CHANNEL_SFX         # 'sound_effects'  : gameplay sounds
```

The layer is **dormant until a game opts in**. Out of the box the channel table
is empty, and `play()` behaves exactly as the mono `MUSIC_ON` / `SOUNDS_ON`
model: no gate beyond `SOUNDS_ON`, no extra volume scaling. Nothing to migrate
in a game that does not want channels.

### `_sound_channels() -> Dictionary`

A game opts in by overriding this hook with its own `soundName -> channel`
table. It is read once and cached, so returning a literal costs nothing per
play:

```gdscript
extends 'res://fox/core/sound.gd'

var SELECT = 'select'
var SWITCH = 'switch'
var EXPLOSION = 'explosion'

func _sound_channels():
  return {
    SELECT: CHANNEL_INTERFACE,
    SWITCH: CHANNEL_INTERFACE,
    EXPLOSION: CHANNEL_SFX,
  }
```

A sound absent from the table resolves to `CHANNEL_SFX`, so a brand new gameplay
sound is gated and levelled correctly before anyone thinks of mapping it.

> ⚠️ Override the **hook**, never a member: the base deliberately holds no
> `_sound_channel` / `_channel_on` / `_channel_volume` variable, because
> GDScript rejects a member redeclared in a subclass, and games that grew this
> layer locally already own those names.

### `is_channel_on(channel)` / `set_channel_on(channel, value)`

```gdscript
Sound.is_channel_on(Sound.CHANNEL_INTERFACE)          # -> bool, defaults to true
Sound.set_channel_on(Sound.CHANNEL_INTERFACE, false)  # mute the UI ticks
```

A muted channel silences `play()` for every sound it holds, on top of the global
`SOUNDS_ON` flag.

### `get_channel_volume(channel)` / `set_channel_volume(channel, value)`

```gdscript
Sound.get_channel_volume(Sound.CHANNEL_SFX)        # -> float, defaults to 0.75
Sound.set_channel_volume(Sound.CHANNEL_SFX, 0.4)
```

The channel volume is **chained** onto the existing `_sound_volume()` hook
rather than replacing it. The final linear scale of a sound is:

```txt
volume argument * _sound_volume(name) * channel volume
```

Calling either setter also arms the layer, so a game that drives its channels
from its settings screen alone, without a table, still gets the gate and the
levels.

### Wiring the settings screen

The bindings of `fox/components/settings` consume these four functions
directly, one channel per toggle plus its slider:

```gdscript
func _prepare_bindings() -> void:
  _bindings['interface'] = {
    get = func(): return Sound.is_channel_on(Sound.CHANNEL_INTERFACE),
    set = func(on): Sound.set_channel_on(Sound.CHANNEL_INTERFACE, on),
    volume_get = func(): return Sound.get_channel_volume(Sound.CHANNEL_INTERFACE),
    volume_set = func(v): Sound.set_channel_volume(Sound.CHANNEL_INTERFACE, v),
  }
```

## Rate-limited playback and fades

### `play_throttled(name, interval_ms, pitch = 1.0)`

Skips a replay of the same sound within `interval_ms`, collapsing a burst into a
single tick: a hover immediately followed by its click, a screen change and the
focus it grabs on entry.

```gdscript
Sound.play_throttled('select', 60)        # one tick per 60 ms at most
Sound.play_throttled('step', 120, 1.2)    # and a raised pitch
```

It returns the player it started, or `null` when the call was skipped. `pitch`
is applied to the player that actually starts.

### `fade_out_and_stop(player, duration = 0.15, delay = 0.0)`

Fades a player out and frees it instead of cutting it dead, which would click on
a ringing sample. Returns the `Tween`, so a caller may kill it when the same
sound restarts before the fade ends:

```gdscript
var player = Sound.play('wind')
var fade = Sound.fade_out_and_stop(player, 0.12)
```

## Playing music

```gdscript
Sound.playMusic('res://assets/musics/track-1.ogg')   # play one track once
Sound.playMusicsInLoop({})                            # cycle through MUSICS forever
Sound.playMusicsInLoop({delay = 2})                   # with an initial delay
Sound.stopMusic()
```

`playMusicsInLoop` advances through `MUSICS` and chains to the next track when
one finishes.

## Mute toggles

```gdscript
Sound.toggleSounds()    # flip SFX on/off
Sound.toggleMusic()     # flip music on/off (adjusts current track volume live)

Sound.isSoundsOn()      # -> bool
Sound.isMusicOn()       # -> bool
```

## Note on `.ogg` looping

`.ogg` files loop by default. For one-shot SFX, disable it:

- select the file in the `FileSystem`,
- open the `Import` tab,
- uncheck `loop`,
- click `Reimport`.
