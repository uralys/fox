extends Node

# ------------------------------------------------------------------------------

func getBundles():
  var file = FileAccess.open("res://fox.config.json", FileAccess.READ)
  var fileContent = file.get_as_text()
  file.close()

  var configJSON = JSON.parse_string(fileContent)
  var bundles = configJSON.bundles
  return bundles
