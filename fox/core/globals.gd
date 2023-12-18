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

var IS_FOX_RUNNER = false

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

  prints('========================================')
  var foxVersion = ProjectSettings.get_setting('fox/version')
  foxVersion = foxVersion if foxVersion else ''
  prints('[🦊 Fox]', foxVersion)
  prints('-------------------------------')
  prints('bundle/id: ' + G.BUNDLE_ID)
  prints('bundle/env: ' + G.ENV)
  prints('bundle/platform: ' + G.PLATFORM)

# ------------------------------------------------------------------------------

func isRunningOnProduction():
  return ENV == RELEASE and not IS_FOX_RUNNER

# ------------------------------------------------------------------------------

func __ansi(o):
  return __.bbcodeToANSI(o) if o is String else o

@warning_ignore('shadowed_global_identifier')
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
