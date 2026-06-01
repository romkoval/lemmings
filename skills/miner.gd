class_name MinerSkill
extends BaseSkill

const TICKS_PER_DIG: int = 8

var tick_counter: int = 0


func get_skill_name() -> String:
	return "miner"


func can_apply(lemming: Lemming) -> bool:
	return lemming.current_state == Lemming.State.WALKING


func apply(lemming: Lemming) -> void:
	tick_counter = 0
	lemming.change_state(Lemming.State.MINING)


func tick(lemming: Lemming) -> void:
	tick_counter += 1
	if tick_counter < TICKS_PER_DIG:
		return
	tick_counter = 0
	var level: Level = _get_level(lemming)
	if level == null:
		lemming.change_state(Lemming.State.WALKING)
		return
	var target: Vector2i = level.world_to_tile(lemming.global_position + Vector2(lemming.direction * 8, 16))
	if level.is_steel_at(target):
		lemming.change_state(Lemming.State.WALKING)
		return
	if not level.remove_terrain_at(target):
		lemming.change_state(Lemming.State.WALKING)
		return
	lemming.global_position += Vector2(lemming.direction * 4, 4)
