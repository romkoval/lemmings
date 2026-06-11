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
			})
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a, b): return str(a["name"]) < str(b["name"]))
	return result


func delete_custom_level(path: String) -> void:
	if path.begins_with(CUSTOM_LEVELS_DIR) and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
