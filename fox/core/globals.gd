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
var VERSION
var VERSION_CODE

var IS_FOX_RUNNER = false

# ------------------------------------------------------------------------------

var W = OS.get_window_size()[0]
var H = OS.get_window_size()[1]

# ------------------------------------------------------------------------------

func isRunningOnProduction():
  return ENV == PRODUCTION and not IS_FOX_RUNNER

# ------------------------------------------------------------------------------
