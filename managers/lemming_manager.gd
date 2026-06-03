class_name LemmingManager
extends Node

# Tracks the live lemmings on the field and drives the Nuke action.
# Win/lose resolution lives in GameManager (driven by per-lemming saved/died
# notifications) — this manager intentionally does NOT duplicate that count.


func get_active_lemmings() -> Array:
	return get_tree().get_nodes_in_group("lemmings")


func get_active_count() -> int:
	return get_active_lemmings().size()


func nuke_all() -> void:
	for lem in get_active_lemmings():
		var l := lem as Lemming
		if l == null:
			continue
		if l.current_state in [Lemming.State.EXITED, Lemming.State.DYING, Lemming.State.SPLAT]:
			continue
		l.start_bomb_countdown()
