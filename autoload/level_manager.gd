extends Node

signal level_loaded(level_data: Dictionary)

const LEVELS_PATH: String = "res://levels/"
const CUSTOM_LEVELS_DIR: String = "user://custom_levels/"

var current_level_data: Dictionary = {}
var available_categories: PackedStringArray = ["fun", "tricky", "taxing", "mayhem"]
# When the player test-plays a level from the editor, this holds the JSON path
# being edited so "back" from the game returns into the editor, not the menu.
var editing_path: String = ""


func get_level_path(category: String, level_number: int) -> String:
	return "%s%s/level_%02d.json" % [LEVELS_PATH, category, level_number]


func get_scene_path(category: String, level_number: int) -> String:
	return "%s%s/level_%02d.tscn" % [LEVELS_PATH, category, level_number]


func load_level_data(category: String, level_number: int) -> Dictionary:
	var path: String = get_level_path(category, level_number)
	if not FileAccess.file_exists(path):
		push_warning("Level file not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		push_error("Failed to parse level: %s" % path)
		return {}
	current_level_data = json.data
	level_loaded.emit(current_level_data)
	return current_level_data


func list_levels(category: String) -> Array:
	var result: Array = []
	var dir_path: String = LEVELS_PATH + category + "/"
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if name.ends_with(".json"):
			result.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result


# ── Custom (player-made) levels ─────────────────────────────────────────────

func ensure_custom_dir() -> void:
	DirAccess.make_dir_recursive_absolute(CUSTOM_LEVELS_DIR)


func load_level_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("Failed to parse level: %s" % path)
		return {}
	return json.data if json.data is Dictionary else {}


func save_level_json(path: String, data: Dictionary) -> bool:
	ensure_custom_dir()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write level: %s" % path)
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	return true


# [{ "path": ..., "name": ..., "id": ... }] for every saved custom level.
func list_custom_levels() -> Array:
	ensure_custom_dir()
	var result: Array = []
	var dir := DirAccess.open(CUSTOM_LEVELS_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var path: String = CUSTOM_LEVELS_DIR + fname
			var d: Dictionary = load_level_json(path)
			result.append({
				"path": path,
				"id": str(d.get("id", fname.get_basename())),
				"name": str(d.get("name", fname.get_basename())),
				# Stamped by a winning test-play; saving from the editor clears
				# it (the meta is rebuilt), so edits always need a fresh proof.
				"verified": bool(d.get("verified", false)),
			})
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a, b): return str(a["name"]) < str(b["name"]))
	return result


# ── Sharing: one-file export/import (US-4.1) ────────────────────────────────
# A .lemlvl bundle is the level JSON with its terrain PNGs embedded as base64 —
# one self-contained file that can be sent through any channel and imported on
# another device.

func export_level(json_path: String) -> String:
	var d: Dictionary = load_level_json(json_path)
	if d.is_empty():
		return ""
	var bundle: Dictionary = d.duplicate(true)
	var dir: String = json_path.get_base_dir()
	for key in ["terrain_mask", "terrain_mat"]:
		var img_name: String = str(d.get(key, ""))
		if img_name != "" and FileAccess.file_exists(dir + "/" + img_name):
			bundle[key + "_b64"] = Marshalls.raw_to_base64(
				FileAccess.get_file_as_bytes(dir + "/" + img_name))
	var out_path: String = CUSTOM_LEVELS_DIR + str(d.get("id", "level")) + ".lemlvl"
	ensure_custom_dir()
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(bundle))
	f.close()
	return out_path


# Returns the imported level's JSON path, or "" if the bundle is invalid.
func import_level(bundle_path: String) -> String:
	if not FileAccess.file_exists(bundle_path):
		return ""
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(bundle_path)) != OK or not (json.data is Dictionary):
		return ""
	var d: Dictionary = json.data
	# Minimal validation: identity plus SOME terrain source.
	if str(d.get("id", "")) == "" or str(d.get("name", "")) == "":
		return ""
	var has_terrain: bool = d.has("terrain_mask_b64") or d.has("terrain_tiles") \
		or d.has("terrain_rects")
	if not has_terrain:
		return ""
	ensure_custom_dir()
	# Never overwrite an existing level: suffix the id on collision.
	var id: String = str(d["id"])
	while FileAccess.file_exists(CUSTOM_LEVELS_DIR + id + ".json"):
		id += "_imp"
	d["id"] = id
	d["custom"] = true
	for key in ["terrain_mask", "terrain_mat"]:
		var b64: String = str(d.get(key + "_b64", ""))
		d.erase(key + "_b64")
		if b64 != "":
			var img_name: String = id + "_" + key.trim_prefix("terrain_") + ".png"
			var fimg := FileAccess.open(CUSTOM_LEVELS_DIR + img_name, FileAccess.WRITE)
			if fimg == null:
				return ""
			fimg.store_buffer(Marshalls.base64_to_raw(b64))
			fimg.close()
			d[key] = img_name
	var out: String = CUSTOM_LEVELS_DIR + id + ".json"
	return out if save_level_json(out, d) else ""


# ── Replays (US-3.1) ────────────────────────────────────────────────────────
# A replay is the event log of one attempt: [{t, type, ...}] keyed by the
# simulation tick. Stored one per level id — the latest finished attempt.

const REPLAYS_DIR: String = "user://replays/"


func save_replay(level_id: String, events: Array) -> bool:
	if level_id == "":
		return false
	DirAccess.make_dir_recursive_absolute(REPLAYS_DIR)
	var file := FileAccess.open(REPLAYS_DIR + level_id + ".json", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"level_id": level_id, "events": events}))
	file.close()
	return true


func load_replay(level_id: String) -> Array:
	var path: String = REPLAYS_DIR + level_id + ".json"
	if not FileAccess.file_exists(path):
		return []
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		return []
	var events = (json.data as Dictionary).get("events", [])
	return events if events is Array else []


func delete_custom_level(path: String) -> void:
	if not path.begins_with(CUSTOM_LEVELS_DIR):
		return
	# A level is the JSON plus its painted terrain PNGs (mask + material).
	var d: Dictionary = load_level_json(path)
	var dir: String = path.get_base_dir()
	for key in ["terrain_mask", "terrain_mat"]:
		var img_name: String = str(d.get(key, ""))
		if img_name != "" and FileAccess.file_exists(dir + "/" + img_name):
			DirAccess.remove_absolute(dir + "/" + img_name)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
