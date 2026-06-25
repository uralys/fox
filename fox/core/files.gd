extends Node

# ------------------------------------------------------------------------------

func getBundles():
  var file = FileAccess.open("res://fox.config.json", FileAccess.READ)
  var fileContent = file.get_as_text()
  file.close()

  var configJSON = JSON.parse_string(fileContent)
  var bundles = configJSON.bundles
  return bundles

# ------------------------------------------------------------------------------
# Rotating local backups for a store_var save file.
#
# Snapshots `path` into `path.bak-0..count-1` (0 = freshest), at most once per
# `min_interval_sec` so frequent saves never churn the backups. The backups sit
# next to the save under a distinct suffix: a cloud sync pattern matching the exact
# save filename leaves them untouched, so they stay local and survive a
# last-writer-wins cloud overwrite — the recovery net for cross-machine conflicts.
# ------------------------------------------------------------------------------

func rotateBackups(path, count := 3, min_interval_sec := 1800):
  if not FileAccess.file_exists(path):
    return
  var newest = backupPath(path, 0)
  if FileAccess.file_exists(newest):
    var age = Time.get_unix_time_from_system() - FileAccess.get_modified_time(newest)
    if age < min_interval_sec:
      return
  var dir = DirAccess.open(path.get_base_dir())
  if dir == null:
    return
  var oldest = backupPath(path, count - 1)
  if FileAccess.file_exists(oldest):
    dir.remove(oldest)
  for i in range(count - 1, 0, -1):
    var src = backupPath(path, i - 1)
    if FileAccess.file_exists(src):
      dir.rename(src, backupPath(path, i))
  dir.copy(path, backupPath(path, 0))

func backupPath(path, index):
  return path + '.bak-' + str(index)

# Read the Variant stored in backup `index` of `path` (0 = freshest). Returns null
# when that backup is missing or empty.
func restoreVar(path, index := 0):
  var backup = backupPath(path, index)
  if not FileAccess.file_exists(backup):
    return null
  var file = FileAccess.open(backup, FileAccess.READ)
  var content = file.get_var()
  file.close()
  return content
