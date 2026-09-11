@tool
extends EditorPlugin

# Registers the Fox default autoloads when the plugin is enabled, and removes
# them again when it is disabled.
#
# A game stays free to override any of them: declaring `autoload/<Name>` in its
# own `project.godot` (e.g. a `G` extending `res://addons/fox/core/globals.gd`)
# makes the plugin skip that entry entirely, and never remove it on disable.
# Only what this plugin added is what this plugin takes back.

# ------------------------------------------------------------------------------

const DEFAULT_AUTOLOADS = {
	'G': 'res://addons/fox/core/globals.gd',
	'DEBUG': 'res://addons/fox/core/debug.gd',
	'Gesture': 'res://addons/fox/autoloads/gesture.gd',
}

# ------------------------------------------------------------------------------
# Optional autoloads, declared by the game itself when it needs them:
#
#   Controls   res://addons/fox/autoloads/controls.gd
#   HotReload  res://addons/fox/autoloads/hot-reload.gd
#   Generate   res://addons/fox/autoloads/generate.gd
#   FrameProbe res://addons/fox/autoloads/frame-probe.gd
#   Keyboard   res://addons/fox/autoloads/keyboard.gd
#   Sound      res://addons/fox/core/sound.gd
#   Files      res://addons/fox/core/files.gd
#   Router     res://addons/fox/core/router.gd
#   Leaderboard res://addons/fox/core/leaderboard.gd
#   AppStore   res://addons/fox/iap/appstore.gd
#   PlayStore  res://addons/fox/iap/playstore.gd
#
# ------------------------------------------------------------------------------

var _registered: Array[String] = []

# ------------------------------------------------------------------------------

func _enter_tree():
	_registered.clear()

	for autoload_name in DEFAULT_AUTOLOADS:
		if ProjectSettings.has_setting('autoload/' + autoload_name):
			continue

		add_autoload_singleton(autoload_name, DEFAULT_AUTOLOADS[autoload_name])
		_registered.append(autoload_name)

# ------------------------------------------------------------------------------

func _exit_tree():
	for autoload_name in _registered:
		remove_autoload_singleton(autoload_name)

	_registered.clear()
