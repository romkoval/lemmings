class_name BomberSkill
extends BaseSkill

const SKILL_NAME: String = "bomber"
const EXPLOSION_RADIUS_TILES: int = 2


func get_skill_name() -> String:
	return SKILL_NAME


func can_apply(lemming: Lemming) -> bool:
	return lemming.current_state != Lemming.State.EXPLODING


func apply(lemming: Lemming) -> void:
	lemming.start_bomb_countdown()


func detonate(lemming: Lemming) -> void:
	var level: Level = _get_level(lemming)
	if level == null:
		return
	var center: Vector2i = level.world_to_tile(lemming.global_position)
	for dy in range(-EXPLOSION_RADIUS_TILES, EXPLOSION_RADIUS_TILES + 1):
		for dx in range(-EXPLOSION_RADIUS_TILES, EXPLOSION_RADIUS_TILES + 1):
			if dx * dx + dy * dy > EXPLOSION_RADIUS_TILES * EXPLOSION_RADIUS_TILES:
				continue
			level.remove_terrain_at(center + Vector2i(dx, dy))
