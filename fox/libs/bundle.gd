# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

class_name Bundle

# ------------------------------------------------------------------------------

static func getPlatform():
  var platform = ProjectSettings.get_setting('app/platform')
  return platform

# ------------------------------------------------------------------------------

static func getStoreUrl(bundleBuildSettings):
  var platform = getPlatform()
  return bundleBuildSettings[platform].storeUrl

# ------------------------------------------------------------------------------
