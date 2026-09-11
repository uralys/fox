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
  if file == null:
    return null
  var content = file.get_var()
  file.close()
  return content

# ------------------------------------------------------------------------------
# Safe reads for a `store_var` save file.
#
# Why three outcomes and not two: a missing file and a damaged file look
# identical to a naive `if not content` test, yet they call for opposite
# reactions. An absent file is a genuine first launch, so seeding defaults and
# persisting them is correct. An unreadable file is a file that IS on disk but
# could not be turned into a usable Variant: locked by another process,
# truncated by a crash, or half written by a cloud sync still in flight.
# Treating that as a first launch resets the progression AND immediately
# overwrites bytes that were still recoverable.
#
# `readVarSafe` names the difference so the caller can branch on it:
#
#   {status: 'absent',     content: null}     nothing on disk: seed and save
#   {status: 'unreadable', content: null}     present but unusable: restore a
#                                             backup, never write over it blindly
#   {status: 'ok',         content: Variant}  a non-empty Dictionary was read
#
# A read that yields an empty or non-Dictionary Variant is reported
# `unreadable` on purpose: storing a save container with `store_var` always
# yields a filled Dictionary, so anything else means the bytes are damaged.
# ------------------------------------------------------------------------------

const READ_ABSENT := 'absent'
const READ_UNREADABLE := 'unreadable'
const READ_OK := 'ok'

func readVarSafe(path) -> Dictionary:
  if not FileAccess.file_exists(path):
    return {'status': READ_ABSENT, 'content': null}

  var file = FileAccess.open(path, FileAccess.READ)
  if file == null:
    G.log('[Files] cannot open ', path, ', open error: ', FileAccess.get_open_error())
    return {'status': READ_UNREADABLE, 'content': null}

  var content = file.get_var()
  file.close()

  if not (content is Dictionary) or content.is_empty():
    G.log('[Files] unusable content read from ', path)
    return {'status': READ_UNREADABLE, 'content': null}

  return {'status': READ_OK, 'content': content}

# ------------------------------------------------------------------------------
# Walk the rotating backups from the freshest to the oldest and return the first
# usable one. A single backup is not enough of a net: the same lock or the same
# in-flight cloud sync that spoiled the live file may also have caught the
# snapshot taken right before it, so the chain keeps trying until a readable
# Dictionary shows up.
#
# Returns the same shape as `readVarSafe`, plus the index that answered:
#
#   {status: 'ok',     content: Variant, index: 0..count-1}
#   {status: 'absent', content: null,    index: -1}   no usable backup left
#
# The caller owns what happens next: adopt the content, then persist it so the
# recovered state becomes the live file again (and re-uploads on the next sync).
# ------------------------------------------------------------------------------

func restoreLatestBackup(path, count := 3) -> Dictionary:
  for index in range(count):
    var content = restoreVar(path, index)
    if content is Dictionary and not content.is_empty():
      G.log('[Files] restored ', path, ' from backup ', index)
      return {'status': READ_OK, 'content': content, 'index': index}

  G.log('[Files] no usable backup for ', path)
  return {'status': READ_ABSENT, 'content': null, 'index': -1}
