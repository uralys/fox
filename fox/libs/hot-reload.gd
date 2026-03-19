extends Node

# ------------------------------------------------------------------------------

var _trigger_path: String
var _timer: Timer

# ------------------------------------------------------------------------------

func _ready():
	_trigger_path = ProjectSettings.globalize_path("res://") + ".hot-reload"
	_timer = Timer.new()
	_timer.wait_time = 0.5
	_timer.timeout.connect(_check_trigger)
	add_child(_timer)
	_timer.start()

# ------------------------------------------------------------------------------

func _check_trigger():
	if not FileAccess.file_exists(_trigger_path):
		return

	var content = FileAccess.get_file_as_string(_trigger_path)
	DirAccess.remove_absolute(_trigger_path)
	prints("[HotReload] change detected:", content.strip_edges())
	Router.reloadCurrentScene()
