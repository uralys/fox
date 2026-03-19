extends RefCounted

# ------------------------------------------------------------------------------
# Navigation state: scene + path of sub-view segments.
#
# path examples:
#   Storybook:    ["Focal Blur"]
#   LevelSelect:  ["3"]              (chapter)
#   Playground:   ["3", "5"]         (chapter, level)
#   UiProposals:  ["level-end-v2", "variant-a"]
# ------------------------------------------------------------------------------

var scene_path: String = ''
var path: Array = []

# ------------------------------------------------------------------------------

func to_json() -> String:
	return JSON.stringify({scene_path = scene_path, path = path})

func load_json(json: String) -> bool:
	if json.is_empty():
		return false
	var parsed = JSON.parse_string(json)
	if not parsed is Dictionary:
		return false
	scene_path = parsed.get('scene_path', '')
	var raw = parsed.get('path', [])
	path = []
	for item in raw:
		path.append(str(item))
	return true
