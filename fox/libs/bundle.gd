# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

class_name Bundle

# ------------------------------------------------------------------------------

static func getPlatform():
  var platform = ProjectSettings.get_setting('bundle/platform')
  return platform

# ------------------------------------------------------------------------------

static func getStoreUrl(bundle):
  var platform = getPlatform()
  return bundle[platform].storeUrl

# ------------------------------------------------------------------------------
