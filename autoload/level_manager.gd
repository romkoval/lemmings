extends Node

signal level_loaded(level_data: Dictionary)

const LEVELS_PATH: String = "res://levels/"

var current_level_data: Dictionary = {}
var available_categories: PackedStringArray = ["fun", "tricky", "taxing", "mayhem"]


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
