# Files

`Files` is an autoload (`fox/core/files.gd`) for project file I/O. It reads the
bundle config and provides **rotating local backups** for a `store_var` save file.

Register it in your project's `[autoload]` section. A project may extend the fox
script to add its own helpers:

```ini
[autoload]

Files="*res://src/core/files.gd"
```

```gdscript
# src/core/files.gd — extend the fox base, add project helpers
extends 'res://fox/core/files.gd'

func read_json(path: String):
    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        return null
    var content = file.get_as_text()
    file.close()
    return JSON.parse_string(content)
```

- [`getBundles()`](#getbundles) — read the bundles from `fox.config.json`
- [Save backups](#save-backups) — `rotateBackups`, `restoreVar`, `backupPath`

## `getBundles()`

Returns the `bundles` array parsed from `res://fox.config.json`.

```gdscript
var bundles = Files.getBundles()
```

## Save backups

A safety net for save files persisted with `FileAccess.store_var()`. Designed for
games that sync their save through **Steam Cloud (or any cloud) with a
last-writer-wins policy**: when you play offline on two machines and reconnect,
the cloud keeps only one file and silently overwrites the other. The backups let
you recover the lost state.

The backups live next to the save under a distinct suffix (`<save>.bak-0..N`), so
a cloud sync pattern matching the **exact** save filename leaves them
untouched — they stay local and survive the overwrite.

> ⚠️ Configure the cloud sync pattern on the exact save filename
> (`saved-data.<bundle>.bin`), **not** a wildcard (`saved-data.<bundle>.*`): a
> wildcard would sync the `.bak-*` files too and defeat the recovery net.

### `rotateBackups(path, count = 3, min_interval_sec = 1800)`

Snapshots the current on-disk `path` into a rotating backup **before** you overwrite
it. `count` backups are kept (`.bak-0` is the freshest). The rotation is throttled:
a new backup is only created when the freshest one is older than `min_interval_sec`
(default 30 min), so frequent saves never churn the backups.

Call it at the top of your save routine:

```gdscript
func save():
    Files.rotateBackups(G.RECORD_PATH)
    var file = FileAccess.open(G.RECORD_PATH, FileAccess.WRITE)
    file.store_var(state)
    file.close()
```

### `restoreVar(path, index = 0)`

Reads back the Variant stored in backup `index` (`0` = freshest). Returns `null`
when that backup is missing or empty.

```gdscript
func restore_backup(index: int = 0) -> bool:
    var content = Files.restoreVar(G.RECORD_PATH, index)
    if content == null:
        return false
    state = content
    save()            # re-persist, so the recovered state re-uploads to the cloud
    return true
```

### `backupPath(path, index)`

Returns the backup path for a given index — `path + '.bak-' + str(index)`. Used
internally by the two helpers; handy if you want to list or clean backups yourself.

```gdscript
var freshest = Files.backupPath(G.RECORD_PATH, 0)   # user://saved-data.<bundle>.bin.bak-0
```
