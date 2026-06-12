extends Node

const SAVE_PATH: String = "user://progress.save"

var completed_levels: Dictionary = {}
# Best result per level id: {"saved": int, "total": int, "time_left": int}.
# "Best" = more saved; on a tie, more time left (US-2.3).
var level_results: Dictionary = {}
var settings: Dictionary = {
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"muted": false,
	"locale": "ru",
}


func _ready() -> void:
	load_progress()


func mark_level_complete(level_id: String) -> void:
	completed_levels[level_id] = true
	save_progress()


func is_level_complete(level_id: String) -> bool:
	return completed_levels.get(level_id, false)


# Record an attempt; keeps only the personal best. Returns true if it was one.
func record_result(level_id: String, saved: int, total: int, time_left: int) -> bool:
	var best: Dictionary = level_results.get(level_id, {})
	var better: bool = best.is_empty() \
		or saved > int(best.get("saved", 0)) \
		or (saved == int(best.get("saved", 0)) and time_left > int(best.get("time_left", 0)))
	if better:
		level_results[level_id] = {"saved": saved, "total": total, "time_left": time_left}
		save_progress()
	return better


func best_result(level_id: String) -> Dictionary:
	return level_results.get(level_id, {})


# Campaign progression: level 1 of every rank is open; each next level opens
# when the previous one in the same rank has been completed.
func is_level_unlocked(category: String, number: int) -> bool:
	if number <= 1:
		return true
	return is_level_complete("%s_%02d" % [category, number - 1])


func save_progress() -> void:
	var data: Dictionary = {
		"completed_levels": completed_levels,
		"level_results": level_results,
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
	level_results = data.get("level_results", {})
	# Merge saved settings over the defaults so a save written by an older build
	# (missing newer keys like "muted") still gets sane values for them.
	var saved: Dictionary = data.get("settings", {})
	for key in saved.keys():
		settings[key] = saved[key]


func reset_progress() -> void:
	completed_levels.clear()
	level_results.clear()
	save_progress()
