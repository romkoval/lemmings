class_name LemmingManager
extends Node

signal all_lemmings_resolved()

var total_to_spawn: int = 0
var spawned: int = 0
var saved: int = 0
var died: int = 0


func setup(total: int) -> void:
	total_to_spawn = total
	spawned = 0
	saved = 0
	died = 0


func get_active_lemmings() -> Array:
	return get_tree().get_nodes_in_group("lemmings")


func get_active_count() -> int:
	return get_active_lemmings().size()


func notify_spawned() -> void:
	spawned += 1


func notify_saved() -> void:
	saved += 1
	_check_done()


func notify_died() -> void:
	died += 1
	_check_done()


func _check_done() -> void:
	if spawned >= total_to_spawn and get_active_count() == 0:
		all_lemmings_resolved.emit()


func nuke_all() -> void:
	for lem in get_active_lemmings():
		var l := lem as Lemming
		if l == null:
			continue
		if l.current_state in [Lemming.State.EXITED, Lemming.State.DYING, Lemming.State.SPLAT]:
			continue
		l.start_bomb_countdown()
