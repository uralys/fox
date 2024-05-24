extends Node

# ------------------------------------------------------------------------------

const RELEASE = 'release'
const DEBUG = 'debug'

# ------------------------------------------------------------------------------
# Fox required globals

var BUNDLE_ID
var BUNDLES
var ENV
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
  G.BUNDLE_ID = ProjectSettings.get_setting('bundle/id')
  G.ENV = ProjectSettings.get_setting('bundle/env')
  G.PLATFORM = ProjectSettings.get_setting('bundle/platform')
  G.VERSION = ProjectSettings.get_setting('bundle/version')
  G.VERSION_CODE = ProjectSettings.get_setting('bundle/versionCode')
  G.RECORD_PATH = 'user://saved-data.' + G.BUNDLE_ID + '.bin'

  G.log('========================================')
  var foxVersion = ProjectSettings.get_setting('fox/version')
  foxVersion = foxVersion if foxVersion else ''
  G.log('[🦊 Fox]', foxVersion)
  G.log('-------------------------------')
  G.log('bundle/id: ' + G.BUNDLE_ID)
  G.log('bundle/env: ' + G.ENV)
  G.log('bundle/platform: ' + G.PLATFORM)

# ------------------------------------------------------------------------------

func __ansi(o):
  return __.bbcodeToANSI(o) if o is String else o

func debug(a, b=null,c=null,d=null,e=null,f=null,g=null):
  if(G.ENV == 'release'): return
  G.log('🫧  [color=magenta](debug)[/color]', a, b, c, d, e, f, g)

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
