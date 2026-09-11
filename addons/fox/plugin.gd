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

# ------------------------------------------------------------------------------
# `add_autoload_singleton()` loads and COMPILES the script before it registers
# the global name. Both `globals.gd` and `debug.gd` reference `G` at parse time,
# so on a project that does not declare the autoloads yet the compilation fails
# with `Identifier not found: G`, and no autoload is ever created.
#
# `globals.gd` therefore addresses itself through `self`, so it compiles before
# any name is registered, and `debug.gd` and `gesture.gd` compile in turn once
# `G` exists. Writing the setting first also registers the name the way a
# hand-written `[autoload]` block does, before the editor call.
#
# Removal lives in `_disable_plugin()`, never in `_exit_tree()`: the editor
# calls `_exit_tree()` on shutdown too, and removing the entries there wiped
# them from `project.godot` on every quit.
# ------------------------------------------------------------------------------

func _enter_tree():
	var changed = false

	for autoload_name in DEFAULT_AUTOLOADS:
		var key = 'autoload/' + autoload_name

		if ProjectSettings.has_setting(key):
			continue

		ProjectSettings.set_setting(key, '*' + DEFAULT_AUTOLOADS[autoload_name])
		add_autoload_singleton(autoload_name, DEFAULT_AUTOLOADS[autoload_name])
		changed = true

	if changed:
		ProjectSettings.save()

# ------------------------------------------------------------------------------

func _disable_plugin():
	var changed = false

	for autoload_name in DEFAULT_AUTOLOADS:
		var key = 'autoload/' + autoload_name

		if not ProjectSettings.has_setting(key):
			continue

		# An entry pointing anywhere else was declared by the game: leave it alone.
		if _autoload_path(ProjectSettings.get_setting(key)) != DEFAULT_AUTOLOADS[autoload_name]:
			continue

		remove_autoload_singleton(autoload_name)
		ProjectSettings.set_setting(key, null)
		changed = true

	if changed:
		ProjectSettings.save()

# ------------------------------------------------------------------------------
# The editor stores an autoload as a uid, so a raw string comparison against the
# `res://` path above would never match what it wrote back.

func _autoload_path(setting_value: String) -> String:
	var path = setting_value.trim_prefix('*')

	if path.begins_with('uid://'):
		var uid = ResourceUID.text_to_id(path)
		if ResourceUID.has_id(uid):
			return ResourceUID.get_id_path(uid)

	return path
