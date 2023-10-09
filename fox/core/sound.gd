# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

var ___node

# ------------------------------------------------------------------------------

var CURRENT_MUSIC
var MUSIC_ON
var SOUNDS_ON

var OGG

# ------------------------------------------------------------------------------

var BUTTON_PRESS = "onButtonPress"

# ------------------------------------------------------------------------------

func _ready():
  ___node = Node.new()
  ___node.process_mode = PROCESS_MODE_ALWAYS
  $'/root/app'.add_child(___node)

# ------------------------------------------------------------------------------

func useSettings(oggFiles, musicOn = true, soundsOn = true):
  OGG = oggFiles
  MUSIC_ON = musicOn
  SOUNDS_ON = soundsOn

# ------------------------------------------------------------------------------

func playMusic(musicName, delay = 0):
  CURRENT_MUSIC = await _play(musicName, delay, -5)
  _refreshMusicVolume()

# ------------------------------------------------------------------------------

func play(soundName, delay = 0, volume = 0):
  if(SOUNDS_ON):
    _play(soundName, delay, volume)

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

func _play(soundName, delay = 0, volume = 0):
  if(delay > 0):
    var _timer = Wait.start(___node, delay)
    await _timer.timeout

  if(DEBUG.SOUNDS):prints('🎵 playing', soundName, 'with delay', delay)

  var assetPath =__.Get(soundName, OGG)
  if(assetPath):
    if(DEBUG.SOUND_OFF):
      prints('🎵 >> debug sound unchecked [', soundName, ']');
    else:
      return _playStream(assetPath, volume)
  else:
    if(DEBUG.SOUNDS):prints('🎵 ❌ sound [', soundName, '] has no super.ogg');

# ------------------------------------------------------------------------------

func _playStream(path, volume = 0):
  var sound = AudioStreamPlayer.new()
  sound.process_mode = PROCESS_MODE_ALWAYS

  var stream = load(path)
  sound.stream = stream
  ___node.add_child(sound)

  sound.play()
  sound.set_volume_db(volume)

  return sound

# ------------------------------------------------------------------------------
