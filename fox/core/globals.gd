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

func isRunningOnProduction():
  return ENV == PRODUCTION and not IS_FOX_RUNNER

# ------------------------------------------------------------------------------
