extends Node

signal level_started(level_id: String)
signal level_completed(saved_count: int, required_count: int)
signal level_failed(reason: String)
signal game_paused(is_paused: bool)

enum GameState { MENU, PLAYING, PAUSED, RESULT }

var current_state: GameState = GameState.MENU
var current_level_id: String = ""
var saved_count: int = 0
var spawned_count: int = 0
var dead_count: int = 0


func set_state(new_state: GameState) -> void:
	current_state = new_state
	if new_state == GameState.PAUSED:
		get_tree().paused = true
		game_paused.emit(true)
	elif new_state == GameState.PLAYING:
		get_tree().paused = false
		game_paused.emit(false)


func start_level(level_id: String) -> void:
	current_level_id = level_id
	saved_count = 0
	spawned_count = 0
	dead_count = 0
	set_state(GameState.PLAYING)
	level_started.emit(level_id)


func notify_lemming_saved() -> void:
	saved_count += 1


func notify_lemming_spawned() -> void:
	spawned_count += 1


func notify_lemming_died() -> void:
	dead_count += 1


func complete_level(required_count: int) -> void:
	set_state(GameState.RESULT)
	if saved_count >= required_count:
		level_completed.emit(saved_count, required_count)
		SaveManager.mark_level_complete(current_level_id)
	else:
		level_failed.emit("not_enough_saved")


func reset() -> void:
	current_level_id = ""
	saved_count = 0
	spawned_count = 0
	dead_count = 0
	set_state(GameState.MENU)
