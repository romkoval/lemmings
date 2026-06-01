extends Node

const SAVE_PATH: String = "user://progress.save"

var completed_levels: Dictionary = {}
var settings: Dictionary = {
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"locale": "ru",
}


func _ready() -> void:
	load_progress()


func mark_level_complete(level_id: String) -> void:
	completed_levels[level_id] = true
	save_progress()


func is_level_complete(level_id: String) -> bool:
	return completed_levels.get(level_id, false)


func save_progress() -> void:
	var data: Dictionary = {
		"completed_levels": completed_levels,
		"settings": settings,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file for writing")
		return
	file.store_string(JSON.stringify(data))
	file.close()


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var data: Dictionary = json.data
	completed_levels = data.get("completed_levels", {})
	settings = data.get("settings", settings)


func reset_progress() -> void:
	completed_levels.clear()
	save_progress()
