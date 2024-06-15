# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

class_name Bundle

# ------------------------------------------------------------------------------

static func getTitle():
  var title = ProjectSettings.get_setting('bundle/title')
  return title

# ------------------------------------------------------------------------------

static func getSubtitle():
  var subtitle = ProjectSettings.get_setting('bundle/subtitle')
  return subtitle

# ------------------------------------------------------------------------------

static func getPlatform():
  var platform = ProjectSettings.get_setting('bundle/platform')
  return platform

# ------------------------------------------------------------------------------

static func getStoreUrl(bundle):
  var platform = getPlatform()
  return bundle[platform].storeUrl

# ------------------------------------------------------------------------------
