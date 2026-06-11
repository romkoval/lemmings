class_name BomberSkill
extends BaseSkill

const EXPLOSION_RADIUS_PX: float = 24.0


func get_skill_name() -> String:
	return "bomber"


func can_apply(lemming: Lemming) -> bool:
	return lemming.current_state != Lemming.State.EXPLODING


func apply(lemming: Lemming) -> void:
	lemming.start_bomb_countdown()


func detonate(lemming: Lemming) -> void:
	var level: Level = _get_level(lemming)
	if level == null:
		return
	# Round crater centred on the body; steel survives the blast.
	level.carve_circle_px(lemming.global_position + Vector2(8, 8), EXPLOSION_RADIUS_PX)
