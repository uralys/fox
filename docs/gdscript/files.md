# Files

`Files` is an autoload (`fox/core/files.gd`) for project file I/O. It reads the
bundle config, provides a **safe read** for a `store_var` save file, and keeps
**rotating local backups** of it.

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

- [`getBundles()`](#getbundles): read the bundles from `fox.config.json`
- [`readVarSafe(path)`](#readvarsafepath): read a save file, absent vs unreadable vs content
- [Save backups](#save-backups): `rotateBackups`, `restoreVar`, `restoreLatestBackup`, `backupPath`

## `getBundles()`

Returns the `bundles` array parsed from `res://fox.config.json`.

```gdscript
var bundles = Files.getBundles()
```

## `readVarSafe(path)`

Reads back the Variant stored at `path` with `FileAccess.store_var()`, and
reports **which of three outcomes** happened. Returns a Dictionary:

| `status` | `content` | meaning |
|---|---|---|
| `'absent'` | `null` | nothing on disk: genuine first launch |
| `'unreadable'` | `null` | the file is there but unusable |
| `'ok'` | the read Variant | a non-empty Dictionary was read |

`'unreadable'` covers every way a present file can fail to produce a usable
state: `FileAccess.open()` returned `null` (the file is locked by another
process), or `get_var()` yielded an empty or non-Dictionary Variant (the file
was truncated by a crash, or a cloud sync is still writing it). Storing a save
container always yields a filled Dictionary, so anything else means damaged
bytes.

Why the distinction matters: an absent file and a damaged file look identical to
a naive `if not content` test, yet they call for opposite reactions. Seeding
defaults is right on a first launch and destructive on a damaged file, because
it resets the progression and then persists over bytes that were still
recoverable.

```gdscript
func load_saved_data():
    var read = Files.readVarSafe(G.RECORD_PATH)

    if read.status == 'absent':
        state = _default_state()
        save()                                  # first launch: persist the seed
        return

    if read.status == 'ok':
        state = read.content
        return

    # Unreadable: try the backups before touching anything on disk.
    var restored = Files.restoreLatestBackup(G.RECORD_PATH)
    if restored.status == 'ok':
        state = restored.content
        save()
        return

    # No usable backup: run on defaults in memory, but do NOT save(): a
    # transient lock or an in-flight cloud file must stay recoverable.
    state = _default_state()
```

> ⚠️ Never `save()` on the unreadable path before the backups are exhausted.
> Under a **last-writer-wins** cloud sync, the file you failed to read may be the
> one the cloud is still downloading from your other machine: writing defaults
> over it turns a transient read failure into a permanent loss of progress, and
> then uploads that loss.

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

### `restoreLatestBackup(path, count = 3)`

Walks the backups from the freshest (`0`) to the oldest and returns the first
usable one, with the same shape as [`readVarSafe`](#readvarsafepath) plus the
index that answered:

| `status` | `content` | `index` |
|---|---|---|
| `'ok'` | the recovered Variant | the backup that answered |
| `'absent'` | `null` | `-1`: no usable backup left |

One backup is not enough of a net: the lock or the in-flight sync that spoiled
the live file may also have caught the snapshot taken just before it, so the
chain keeps trying.

```gdscript
var restored = Files.restoreLatestBackup(G.RECORD_PATH)
if restored.status == 'ok':
    state = restored.content
    save()            # re-persist, so the recovered state re-uploads to the cloud
```

### `backupPath(path, index)`

Returns the backup path for a given index — `path + '.bak-' + str(index)`. Used
internally by the two helpers; handy if you want to list or clean backups yourself.

```gdscript
var freshest = Files.backupPath(G.RECORD_PATH, 0)   # user://saved-data.<bundle>.bin.bak-0
```
