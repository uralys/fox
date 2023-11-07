extends Node

# ------------------------------------------------------------------------------

const PRODUCTION = 'production'
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

var W = DisplayServer.window_get_size()[0]
var H = DisplayServer.window_get_size()[1]

# ------------------------------------------------------------------------------

# use this global state barely;
# e.g. Draggable objects VS Draggable camera -> we cannot use a local camera control
var state = {}

# ------------------------------------------------------------------------------

func isRunningOnProduction():
  return ENV == PRODUCTION and not IS_FOX_RUNNER

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
