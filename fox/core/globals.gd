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

var W = get_window().get_size()[0]
var H = get_window().get_size()[1]

# ------------------------------------------------------------------------------

func isRunningOnProduction():
  return ENV == PRODUCTION and not IS_FOX_RUNNER

# ------------------------------------------------------------------------------
