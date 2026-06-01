class_name LevelExit
extends Area2D

signal lemming_exited(lemming: Lemming)


func _ready() -> void:
	add_to_group("exits")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	var lem := body as Lemming
	if lem == null:
		return
	if lem.current_state == Lemming.State.EXITED:
		return
	AudioManager.play_sfx("yippee")
	lemming_exited.emit(lem)
	lem.mark_saved()
