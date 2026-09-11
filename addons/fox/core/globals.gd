extends Node

# ------------------------------------------------------------------------------

const RELEASE = 'release'
const DEBUG = 'debug'
const DEMO = 'demo'

# Distribution targets. A build is (env, target): the env says what it CONTAINS,
# the target says where it is published and which store plumbing it carries. The
# same demo goes to Steam with an app id and a Workshop, and to itch.io with
# neither — so a store question is never answered by reading G.ENV.
const STEAM = 'steam'
const ITCH = 'itch'

# ------------------------------------------------------------------------------
# Fox required globals

var BUNDLE_ID
var BUNDLES
var ENV
var TARGET
var PLATFORM
var RECORD_PATH
var VERSION
var VERSION_CODE

# ------------------------------------------------------------------------------

var W
var H
var SCREEN_CENTER

# ------------------------------------------------------------------------------

func _ready():
  self.BUNDLE_ID = ProjectSettings.get_setting('bundle/id')
  self.ENV = ProjectSettings.get_setting('bundle/env')
  # A project that predates the target axis has no setting: it ships to Steam.
  self.TARGET = ProjectSettings.get_setting('bundle/target', STEAM)
  self.PLATFORM = ProjectSettings.get_setting('bundle/platform')
  self.VERSION = ProjectSettings.get_setting('bundle/version')
  self.VERSION_CODE = ProjectSettings.get_setting('bundle/versionCode')
  self.RECORD_PATH = 'user://saved-data.' + self.BUNDLE_ID + _recordSuffix(self.ENV) + '.bin'

  self.log('========================================')
  self.log('[🦊 Fox]', _foxVersion())
  self.log('-------------------------------')
  self.log('bundle/id: ' + self.BUNDLE_ID)
  self.log('bundle/env: ' + self.ENV)
  self.log('bundle/target: ' + self.TARGET)
  self.log('bundle/platform: ' + self.PLATFORM)

# The addon declares its own version in `plugin.cfg`, which follows the mounted
# tree; the `fox/version` project setting is the legacy mount's answer and goes
# stale the moment the addon moves without it.
#
# A linked mount rides the fox checkout, so that version is whatever the working
# tree holds right now and NOT a released one: the boot line says so, otherwise
# a build log would claim a version nobody can go back to.
func _foxVersion() -> String:
  var version = ''

  var config = ConfigFile.new()
  if config.load('res://addons/fox/plugin.cfg') == OK:
    version = config.get_value('plugin', 'version', '')

  if version == '':
    version = ProjectSettings.get_setting('fox/version', '')

  var addons = DirAccess.open('res://addons')
  if addons and addons.is_link('fox'):
    version += ' (symlinked)'

  return version

# ------------------------------------------------------------------------------

# A demo ships as a separate Steam app (own app id, own Cloud) but shares the bundle
# id with the full game. Key the save file on the demo env so the two variants never
# share a local file, and each app's Cloud syncs its own save filename. Non-demo envs
# keep the plain `saved-data.<bundle>.bin` (backward compatible).
func _recordSuffix(env):
  return '.demo' if env == DEMO else ''

# True when the build is aimed at Steam, and therefore when Steam plumbing (the
# SDK init, the overlay, the Workshop, Cloud) is expected to exist at all. This is
# the ONLY question a store feature should ask — never `ENV == DEMO`.
func isSteamTarget() -> bool:
  return TARGET == STEAM

# ------------------------------------------------------------------------------

func screenSize() -> Vector2:
  if W and H:
    return Vector2(W, H)
  return $/root.get_viewport().get_visible_rect().size

func screenCenter() -> Vector2:
  if SCREEN_CENTER:
    return SCREEN_CENTER
  return screenSize() / 2.0

# ------------------------------------------------------------------------------

func __ansi(o):
  return __.bbcodeToANSI(o) if o is String else o

func debug(a, b=null,c=null,d=null,e=null,f=null,g=null):
  if(self.ENV == 'release'): return
  self.log('🫧  [color=magenta](debug)[/color]', a, b, c, d, e, f, g)

func log(a, b=null,c=null,d=null,e=null,f=null,g=null,h=null):
  prints(__ansi(a),
    __ansi(b) if b != null else '',
    __ansi(c) if c != null else '',
    __ansi(d) if d != null else '',
    __ansi(e) if e != null else '',
    __ansi(f) if f != null else '',
    __ansi(g) if g != null else '',
    __ansi(h) if h != null else ''
  )
