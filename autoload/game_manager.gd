extends Node

signal level_started(level_id: String)
signal level_completed(saved_count: int, required_count: int)
signal level_failed(reason: String)
signal game_paused(is_paused: bool)
signal all_lemmings_resolved()

enum GameState { MENU, PLAYING, PAUSED, RESULT }

var current_state: GameState = GameState.MENU
var current_level_id: String = ""
var total_lemmings: int = 0
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


func start_level(level_id: String, total: int = 0) -> void:
	current_level_id = level_id
	total_lemmings = total
	saved_count = 0
	spawned_count = 0
	dead_count = 0
	set_state(GameState.PLAYING)
	level_started.emit(level_id)


func notify_lemming_saved() -> void:
	saved_count += 1
	_check_resolved()


func notify_lemming_spawned() -> void:
	spawned_count += 1


func notify_lemming_died() -> void:
	dead_count += 1
	_check_resolved()


# A level is resolved once every lemming that will ever spawn has reached a
# terminal state (saved or dead). Emitted exactly once while PLAYING.
func _check_resolved() -> void:
	if current_state != GameState.PLAYING:
		return
	if total_lemmings <= 0 or spawned_count < total_lemmings:
		return
	if saved_count + dead_count < spawned_count:
		return
	all_lemmings_resolved.emit()


func complete_level(required_count: int) -> void:
	# Idempotent: resolution and timer-expiry can both fire — only the first wins.
	if current_state == GameState.RESULT:
		return
	set_state(GameState.RESULT)
	if saved_count >= required_count:
		level_completed.emit(saved_count, required_count)
		SaveManager.mark_level_complete(current_level_id)
	else:
		level_failed.emit("not_enough_saved")


func reset() -> void:
	current_level_id = ""
	total_lemmings = 0
	saved_count = 0
	spawned_count = 0
	dead_count = 0
	set_state(GameState.MENU)
