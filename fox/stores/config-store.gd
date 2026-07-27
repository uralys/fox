@tool
class_name ConfigStore
extends RefCounted

# ------------------------------------------------------------------------------
#
# Generic persistence layer for slugified .tres resources living under a folder.
# Pure CRUD over a directory of config resources, parameterised by `dir` so a game
# can reuse the exact same frozen shape for any config family (biomes, worlds, ...).
#
# The id of a config IS its file name (basename), so this layer maps id <-> path
# deterministically: `path_for(dir, id) == dir + id + ".tres"`. Ids are produced by
# slugifying a display name (lowercase, non-alphanumeric -> dashes, collapsed and
# trimmed) with a -2/-3/... suffix on collision, falling back to `fallback_slug`
# when the name slugifies to empty.
#
# No dependency on any concrete config class, on the editor or on its filesystem
# interface: re-scanning the editor filesystem after a create/delete is the caller's
# job, not this layer's. Configs persist in res:// (project data), never user://.
#
# This holds the verbatim shared by the mirror game stores (biome / world). The tiny
# per-game divergences stay in the calling store:
# - the concrete resource class is instantiated by the caller and handed to
#   `create` already built (e.g. the game's config resource with its carriers ready),
# - `duplicate_config` takes an optional `on_copy` hook the caller uses to run the
#   same game-specific init on the deep copy (e.g. ensure_carriers()),
# - `list_entries` reads `display_name` opportunistically (only when the resource
#   exposes that property).
#
# ------------------------------------------------------------------------------


# Lists the config ids (file basenames) of every .tres in `dir`, sorted. Creates
# the directory if it is missing so the first create has somewhere to write.
static func list_ids(dir: String) -> Array:
	_ensure_dir(dir)
	var ids: Array = []
	var handle := DirAccess.open(dir)
	if handle == null:
		return ids
	handle.list_dir_begin()
	var name := handle.get_next()
	while name != "":
		if not handle.current_is_dir() and name.get_extension() == "tres":
			ids.append(name.get_basename())
		name = handle.get_next()
	handle.list_dir_end()
	ids.sort()
	return ids


# Lists every config as {id, name}, sorted by id — id is the file basename, name is
# the resource's display_name (falling back to the id when empty or absent), for
# showing configs by name in a picker.
static func list_entries(dir: String) -> Array:
	var entries: Array = []
	for id_value in list_ids(dir):
		var id := String(id_value)
		var config := load_config(dir, id)
		var display := id
		if config != null and "display_name" in config:
			var name := str(config.display_name).strip_edges()
			if not name.is_empty():
				display = name
		entries.append({"id": id, "name": display})
	return entries


static func path_for(dir: String, id: String) -> String:
	return dir + id + ".tres"


# Loads the config with the given id, or null when it is missing.
static func load_config(dir: String, id: String) -> Resource:
	var path := path_for(dir, id)
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path)


# Saves the config to the path derived from its id. When `id` is omitted the id is
# read back from the config's own resource_path basename (its bound file).
static func save_config(dir: String, config: Resource, id: String = "") -> Error:
	if config == null:
		return ERR_INVALID_PARAMETER
	_ensure_dir(dir)
	var target_id := id if id != "" else _id_of(config)
	return ResourceSaver.save(config, path_for(dir, target_id))


# Persists a freshly built config: computes a unique slug from its display_name,
# binds it to that path (take_over_path) and saves. The caller instantiates the
# concrete resource (setting display_name and running any game-specific init) and
# hands it here — this layer stays resource-class agnostic.
static func create(dir: String, config: Resource, fallback_slug: String) -> Resource:
	if config == null:
		return null
	return _persist_new(dir, config, fallback_slug)


# Duplicates an existing config (deep) under a new unique slug, saved and bound.
# `on_copy` (optional) runs on the deep copy before saving so the caller can apply
# the same game-specific init as create (e.g. ensure_carriers()).
static func duplicate_config(dir: String, id: String, new_name: String, fallback_slug: String, on_copy: Callable = Callable()) -> Resource:
	var source := load_config(dir, id)
	if source == null:
		return null
	var config: Resource = source.duplicate(true)
	if "display_name" in config:
		config.display_name = new_name
	if on_copy.is_valid():
		on_copy.call(config)
	return _persist_new(dir, config, fallback_slug)


# Renames a config: updates its display_name and, when the slugified new name yields
# a different id, moves the .tres on disk to the new path (the id IS the file
# basename). Returns the resulting id ("" on failure) so callers can reselect it.
static func rename(dir: String, id: String, new_name: String, fallback_slug: String) -> String:
	var config := load_config(dir, id)
	if config == null:
		return ""
	if "display_name" in config:
		config.display_name = new_name
	var desired := _slugify(new_name)
	if desired == "" or desired == id:
		return id if save_config(dir, config, id) == OK else ""
	var new_id := _unique_slug(dir, new_name, fallback_slug)
	var new_path := path_for(dir, new_id)
	config.take_over_path(new_path)
	if ResourceSaver.save(config, new_path) != OK:
		return ""
	var old_path := path_for(dir, id)
	if FileAccess.file_exists(old_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(old_path))
	return new_id


# Removes the config's .tres from disk. Re-scanning the editor filesystem afterwards
# is the caller's job (no editor dependency here).
static func delete(dir: String, id: String) -> Error:
	var path := path_for(dir, id)
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ------------------------------------------------------------------------------


static func _persist_new(dir: String, config: Resource, fallback_slug: String) -> Resource:
	_ensure_dir(dir)
	var path := path_for(dir, _unique_slug(dir, _display_name_of(config), fallback_slug))
	config.take_over_path(path)
	if ResourceSaver.save(config, path) != OK:
		return null
	return config


static func _ensure_dir(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))


static func _id_of(config: Resource) -> String:
	if config == null:
		return ""
	return config.resource_path.get_file().get_basename()


static func _display_name_of(config: Resource) -> String:
	if config != null and "display_name" in config:
		return str(config.display_name)
	return ""


# Slugifies a display name (lowercase, non-alphanumeric -> dashes, collapsed and
# trimmed) and appends -2/-3/... until the id is free in `dir`. Falls back to
# `fallback_slug` when the name slugifies to empty.
static func _unique_slug(dir: String, display_name: String, fallback_slug: String) -> String:
	var base := _slugify(display_name)
	if base == "":
		base = fallback_slug
	var taken := list_ids(dir)
	if not taken.has(base):
		return base
	var n := 2
	while taken.has(base + "-" + str(n)):
		n += 1
	return base + "-" + str(n)


static func _slugify(text: String) -> String:
	var lower := text.strip_edges().to_lower()
	var out := ""
	for i in lower.length():
		var c := lower[i]
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
		else:
			out += "-"
	while out.contains("--"):
		out = out.replace("--", "-")
	return out.lstrip("-").rstrip("-")
