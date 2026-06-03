class_name DiggerSkill
extends BaseSkill

const TICKS_PER_DIG: int = 6

var tick_counter: int = 0


func get_skill_name() -> String:
	return "digger"


func can_apply(lemming: Lemming) -> bool:
	return lemming.current_state == Lemming.State.WALKING


func apply(lemming: Lemming) -> void:
	tick_counter = 0
	lemming.change_state(Lemming.State.DIGGING)


func tick(lemming: Lemming) -> void:
	tick_counter += 1
	if tick_counter < TICKS_PER_DIG:
		return
	tick_counter = 0
	var level: Level = _get_level(lemming)
	if level == null:
		lemming.change_state(Lemming.State.WALKING)
		return
	# Probe the tile the feet rest on. The body settles ~1px above the floor, so
	# feet (origin + 16) can read as the empty cell *above* the floor — sample a
	# couple px lower (centre-x) to reliably hit the floor tile beneath.
	var target: Vector2i = level.world_to_tile(lemming.global_position + Vector2(8, 18))
	if level.is_steel_at(target):
		lemming.change_state(Lemming.State.WALKING)
		return
	if not level.remove_terrain_at(target):
		lemming.change_state(Lemming.State.WALKING)
		return
	# Drop a full tile onto the freshly cleared cell so the next probe lines up.
	lemming.global_position.y = target.y * Level.TILE_SIZE
