extends Node

# ------------------------------------------------------------------------------

const PRODUCTION = 'production'
const DEBUG = 'debug'

# ------------------------------------------------------------------------------
# Fox required globals

var BUNDLE_ID
var BUNDLES
var ENV
var VERSION
var VERSION_CODE

var IS_FOX_RUNNER = false

func isRunningOnProduction():
  return ENV == PRODUCTION and not IS_FOX_RUNNER

# ------------------------------------------------------------------------------
