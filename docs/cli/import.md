# 📥 importing assets

```sh
fox import           # incremental: only outdated assets
fox import --force   # wipes .godot/imported, reimports everything
```

`fox import` runs `godot --headless --path . --import`, which boots the editor
without its window: same `EditorFileSystem` scan as opening the project
(autoloads, enabled editor plugins, `EditorScenePostImport` scripts, per-file
`.import` settings), then quits once the import is done.

It is **incremental**, exactly like the editor: an asset whose source and import
settings did not change is not reimported. `--force` deletes the
`.godot/imported` cache first, so everything is rebuilt — the `.import` files
are never touched, your import settings are preserved.

Being headless, there is no `RenderingDevice`: GPU texture compression falls
back to the CPU compressor (slower, same format) and no filesystem thumbnails
are generated. Godot returns `0` even when an importer logs an error, so read
the output rather than trusting the exit code.

Useful before any headless run (tests, screenshots, export) or after a batch of
assets landed on disk, to avoid opening the editor just for that.

`fox upgrade` and `fox link` run it for you once they have written the mount,
see [pinning a version](./versioning.md).
