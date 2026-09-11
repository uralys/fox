# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

var ___node
var _verbose = true

# ------------------------------------------------------------------------------

var CURRENT_MUSIC_CURSOR = -1
var CURRENT_MUSIC
var MUSIC_ON
var SOUNDS_ON

var OGG

# ------------------------------------------------------------------------------

var BUTTON_PRESS = "onButtonPress"

# ------------------------------------------------------------------------------

func init(musicOn = true, soundsOn = true):
  OGG = self.oggFiles
  MUSIC_ON = musicOn
  SOUNDS_ON = soundsOn

  # Re-init (e.g. after Reset Data): drop the previous host node so its still-playing
  # music/SFX are freed and audio restarts from a clean state instead of doubling up.
  if(___node and is_instance_valid(___node)):
    ___node.queue_free()
  CURRENT_MUSIC = null
  CURRENT_MUSIC_CURSOR = -1

  ___node = Node.new()
  ___node.process_mode = PROCESS_MODE_ALWAYS
  $'/root/app'.add_child(___node)

# ------------------------------------------------------------------------------

func playMusicsInLoop(options):
  var delay = __.GetOr(0, 'delay', options)
  if(delay > 0):
    await Wait.forSomeTime(___node, delay).timeout

  CURRENT_MUSIC_CURSOR = (CURRENT_MUSIC_CURSOR+1) % Sound.MUSICS.size()
  var musicName = Sound.MUSICS[CURRENT_MUSIC_CURSOR]
  await playMusic(musicName)

  # CURRENT_MUSIC.seek(145) # to debug .ogg encoding

  if(CURRENT_MUSIC):
    CURRENT_MUSIC.connect('finished', func():
      stopMusic()
      playMusicsInLoop(options)
    )

# ------------------------------------------------------------------------------

func playMusic(musicName, delay = 0):
  CURRENT_MUSIC = await _play(musicName, delay, false)
  _refreshMusicVolume()

# ------------------------------------------------------------------------------

func play(soundName, delay = 0, volume = 1.0):
  if(SOUNDS_ON and _channel_allows(soundName)):
    var player = await _play(soundName, delay)
    if(player):
      _apply_sfx_volume(player, soundName, volume)
    return player

# ------------------------------------------------------------------------------

func stopMusic():
  if(not CURRENT_MUSIC):
    return

  CURRENT_MUSIC.stop()
  ___node.remove_child(CURRENT_MUSIC)
  CURRENT_MUSIC.queue_free()
  CURRENT_MUSIC = null

# ------------------------------------------------------------------------------

func _refreshMusicVolume():
  if(not CURRENT_MUSIC):
    return

  var volume = 0 if(MUSIC_ON) else -100
  CURRENT_MUSIC.set_volume_db(volume)

func toggleSounds():
  SOUNDS_ON = not SOUNDS_ON

func toggleMusic():
  MUSIC_ON = not MUSIC_ON
  _refreshMusicVolume()

func isSoundsOn():
  return SOUNDS_ON

func isMusicOn():
  return MUSIC_ON

# ------------------------------------------------------------------------------
# Native SFX volume (additive)
# ------------------------------------------------------------------------------

# Per-sound linear volume scale (1.0 = unchanged). Games override this hook to
# expose a per-key volume table / channel mix; the returned scale is multiplied
# by the explicit `volume` argument passed to play(). Left a no-op here so the
# base behaviour is byte-identical when neither the arg nor an override is used.
func _sound_volume(_soundName):
  return 1.0

# Apply the combined linear volume to a freshly started player. A combined scale
# of exactly 1.0 leaves the player untouched (0 dB — previous behaviour); 0 or
# below is floored to silence to avoid linear_to_db(0) == -inf.
func _apply_sfx_volume(player, soundName, volume):
  var scale = volume * _sound_volume(soundName) * _channel_scale(soundName)
  if(scale == 1.0):
    return
  player.volume_db = linear_to_db(scale) if scale > 0 else -80.0

# ==============================================================================
# Audio channels (superset of the MUSIC_ON / SOUNDS_ON model)
#
# Consolidated from the game that grew this layer beside the shared base: every
# SFX belongs to a channel carrying its own on-flag and its own linear volume,
# so a player can silence the interface ticks while keeping the gameplay sounds,
# and level each group on its own. Music keeps its separate streamed path and is
# not a channel.
#
# The layer is DORMANT until a game opts in. `_sound_channels()` returns an empty
# table here, and while it is empty and no channel has been touched, play() keeps
# the exact behaviour of the mono model: no gate beyond SOUNDS_ON, no extra
# volume scaling. A game opts in by overriding the hook with its own
# soundName -> channel table (or by calling a setter, for a game driving the
# channels from its settings screen only). From then on every sound resolves to a
# channel, an unmapped one falling back to CHANNEL_SFX so a brand new gameplay
# sound is gated and levelled correctly before anyone thinks of mapping it.
#
# The channel volume is CHAINED onto the existing `_sound_volume` hook rather
# than replacing it. The final linear scale of a sound is:
#   volume argument * _sound_volume(name) * channel volume
#
# The exposed names are what the settings component consumes through its
# `{get, set, volume_get, volume_set}` bindings: is_channel_on / set_channel_on /
# get_channel_volume / set_channel_volume.
#
# ⚠️ The table and the channel state are deliberately NOT named `_sound_channel`,
# `_channel_on` or `_channel_volume`: a game that grew this layer locally already
# declares members under those names, and GDScript rejects a member redeclared in
# a subclass. Everything a game overrides is therefore a FUNCTION, which a
# subclass may always replace.
# ==============================================================================

const CHANNEL_INTERFACE := 'interface'
const CHANNEL_SFX := 'sound_effects'

# Level a channel starts at: loud enough to be heard, low enough to leave the
# player room to push it up.
const DEFAULT_CHANNEL_VOLUME := 0.75

# soundName -> channel. EMPTY in the base: a game overrides this hook with its
# own table, and doing so is what turns the layer on. Read once and cached, so a
# game may return a literal without paying for it on every play().
func _sound_channels() -> Dictionary:
  return {}

var _channel_table = null
var _channel_states := {CHANNEL_INTERFACE: true, CHANNEL_SFX: true}
var _channel_volumes := {CHANNEL_INTERFACE: DEFAULT_CHANNEL_VOLUME, CHANNEL_SFX: DEFAULT_CHANNEL_VOLUME}

# Raised by the setters, so a game that never maps a table still gets the gate
# and the levels once its settings screen touches a channel.
var _channels_configured := false

func _channel_map() -> Dictionary:
  if(_channel_table == null):
    _channel_table = _sound_channels()
  return _channel_table

func _channels_active() -> bool:
  return _channels_configured or not _channel_map().is_empty()

func _channel_of(soundName) -> String:
  return _channel_map().get(soundName, CHANNEL_SFX)

func _channel_allows(soundName) -> bool:
  if(not _channels_active()):
    return true
  return is_channel_on(_channel_of(soundName))

func _channel_scale(soundName) -> float:
  if(not _channels_active()):
    return 1.0
  return get_channel_volume(_channel_of(soundName))

func is_channel_on(channel: String) -> bool:
  return _channel_states.get(channel, true)

func set_channel_on(channel: String, value: bool) -> void:
  _channels_configured = true
  _channel_states[channel] = value

func get_channel_volume(channel: String) -> float:
  return _channel_volumes.get(channel, DEFAULT_CHANNEL_VOLUME)

func set_channel_volume(channel: String, value: float) -> void:
  _channels_configured = true
  _channel_volumes[channel] = value

# ------------------------------------------------------------------------------
# Rate-limited playback
# ------------------------------------------------------------------------------

# soundName -> last start, in milliseconds.
var _throttle_ms := {}

# Skips a replay of the same sound within `interval_ms`, collapsing a burst into
# a single tick: a hover immediately followed by its click, a screen change and
# the focus it grabs on entry. `pitch` is applied to the player that starts.
func play_throttled(soundName, interval_ms: int, pitch = 1.0):
  var now = Time.get_ticks_msec()
  if(now - int(_throttle_ms.get(soundName, -100000)) < interval_ms):
    return null
  _throttle_ms[soundName] = now

  var player = await play(soundName)
  if(player and pitch != 1.0):
    player.pitch_scale = pitch
  return player

# ------------------------------------------------------------------------------

# Fades a player out and frees it instead of cutting it dead: a hard stop on a
# ringing sample clicks. Returns the Tween, so a caller may kill it when the same
# sound restarts before the fade ends.
func fade_out_and_stop(player, duration: float = 0.15, delay: float = 0.0) -> Tween:
  if(not player or not is_instance_valid(player)):
    return null

  var tween = player.create_tween()
  if(delay > 0.0):
    tween.tween_interval(delay)
  tween.tween_property(player, 'volume_db', -80.0, duration)
  tween.tween_callback(player.queue_free)
  return tween

# ------------------------------------------------------------------------------

func _play(soundName, delay = 0, duck = true):
  if(delay > 0):
    await Wait.forSomeTime(___node, delay).timeout

  var assetPath =__.Get(soundName, OGG)
  if(assetPath):
    if(DEBUG.SOUND_OFF):
      G.debug('🎵 >> DEBUG.SOUND_OFF [', soundName, ']');
    else:
      return _playStream(assetPath, duck)
  else:
    if(_verbose):G.debug('[Sound] ❌ sound [', soundName, '] has no super.ogg');

# ------------------------------------------------------------------------------

func _playStream(path, duck = true):
  var sound = AudioStreamPlayer.new()
  sound.process_mode = PROCESS_MODE_ALWAYS

  var stream = load(path)
  sound.stream = stream
  ___node.add_child(sound)

  # Same-sample ducking: fade out any older instance of this exact sample that is
  # still ringing, then track this one. Keeps at most one audible instance per
  # sample so tight retrigger bursts (rooms appearing / tilting / vanishing in a
  # row) are heard cleanly instead of piling up into a flood.
  if(duck):
    _duck_previous(path)
    _track_player(path, sound)

  sound.play()

  return sound

# ------------------------------------------------------------------------------
# Same-sample ducking
# ------------------------------------------------------------------------------

# Fade applied when a sample retriggers — short enough to get out of the way,
# long enough to avoid a click ("sans écrabouiller").
const DUCK_FADE_SEC := 0.08

# Relative drop applied to the immediately-previous instance: a duck, not a kill.
# It stays audible underneath the new one, just stepped back.
const DUCK_REDUCTION_DB := -8.0

# path -> Array[AudioStreamPlayer] currently ringing for that sample (oldest first).
var _active_players := {}

func _track_player(path, player):
  var list = _active_players.get(path, [])
  list.append(player)
  _active_players[path] = list
  player.finished.connect(func(): _forget_player(path, player))

func _forget_player(path, player):
  var list = _active_players.get(path, [])
  list.erase(player)
  if(list.is_empty()):
    _active_players.erase(path)
  else:
    _active_players[path] = list
  if(is_instance_valid(player)):
    player.queue_free()

# Step back the immediately-previous instance (kept audible underneath the new
# one), and fully retire any older instances so a tight burst still collapses to
# ~two ringing voices instead of stacking into a flood.
func _duck_previous(path):
  var list = _active_players.get(path, [])
  var survivors = []
  for i in list.size():
    var player = list[i]
    if(not is_instance_valid(player)):
      continue
    var tween = player.create_tween()
    if(i == list.size() - 1 and player.playing):
      tween.tween_property(player, 'volume_db', player.volume_db + DUCK_REDUCTION_DB, DUCK_FADE_SEC)
      survivors.append(player)
    else:
      tween.tween_property(player, 'volume_db', -80.0, DUCK_FADE_SEC)
      tween.tween_callback(player.queue_free)
  _active_players[path] = survivors

# ------------------------------------------------------------------------------
