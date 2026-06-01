class_name BuilderSkill
extends BaseSkill

const SKILL_NAME: String = "builder"
const MAX_STEPS: int = 12
const TICKS_PER_STEP: int = 12

var steps_placed: int = 0
var tick_counter: int = 0


func get_skill_name() -> String:
	return SKILL_NAME


func can_apply(lemming: Lemming) -> bool:
	return lemming.current_state == Lemming.State.WALKING


func apply(lemming: Lemming) -> void:
	steps_placed = 0
	tick_counter = 0
	lemming.change_state(Lemming.State.BUILDING)


func tick(lemming: Lemming) -> void:
	tick_counter += 1
	if tick_counter < TICKS_PER_STEP:
		return
	tick_counter = 0
	if steps_placed >= MAX_STEPS:
		lemming.change_state(Lemming.State.WALKING)
		return
	var level: Level = _get_level(lemming)
	if level == null:
		lemming.change_state(Lemming.State.WALKING)
		return
	var tile: Vector2i = level.world_to_tile(lemming.global_position + Vector2(lemming.direction * 8, 16))
	level.add_terrain_at(tile, 0, Vector2i.ZERO)
	lemming.global_position += Vector2(lemming.direction * 8, -4)
	steps_placed += 1
	if steps_placed >= MAX_STEPS:
		lemming.change_state(Lemming.State.WALKING)
