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
  if(SOUNDS_ON):
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
  var scale = volume * _sound_volume(soundName)
  if(scale == 1.0):
    return
  player.volume_db = linear_to_db(scale) if scale > 0 else -80.0

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
