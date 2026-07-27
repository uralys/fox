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
