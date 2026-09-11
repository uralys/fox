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

static func getAppId():
  var bundleId = ProjectSettings.get_setting('bundle/id')
  var bundles = Files.getBundles()
  return bundles[bundleId].iOS.appId

# ------------------------------------------------------------------------------

static func getStoreUrl():
  var platform = getPlatform()
  var bundleId = ProjectSettings.get_setting('bundle/id')
  var bundles = Files.getBundles()
  return bundles[bundleId][platform].storeUrl

# ------------------------------------------------------------------------------
