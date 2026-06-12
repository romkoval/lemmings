class_name MinerSkill
extends BaseSkill

# Mines a diagonal tunnel down-forward: each swing carves a body-sized pocket
# ahead and slightly below, then the miner steps 4px forward and 4px down into
# it, descending at 45°/2 like the original.

const TICKS_PER_SWING: int = 8
const POCKET_W: int = 16
const POCKET_H: int = 17

var tick_counter: int = 0


func get_skill_name() -> String:
	return "miner"


func can_apply(lemming: Lemming) -> bool:
	return lemming.current_state == Lemming.State.WALKING


func needs_tick() -> bool:
	return true


func apply(lemming: Lemming) -> void:
	tick_counter = 0
	lemming.change_state(Lemming.State.MINING)


func tick(lemming: Lemming) -> void:
	tick_counter += 1
	if tick_counter < TICKS_PER_SWING:
		return
	tick_counter = 0
	var level: Level = _get_level(lemming)
	if level == null:
		lemming.change_state(Lemming.State.WALKING)
		return
	var fx: int = lemming.feet_x()
	var fy: int = lemming.feet_y()
	# Pocket ahead of the body, dipping 4px below the feet — the space the next
	# step descends into.
	var x0: int = fx + 1 if lemming.direction > 0 else fx - 1 - POCKET_W
	var pocket := Rect2i(x0, fy - (POCKET_H - 5), POCKET_W, POCKET_H)
	# Steel or a one-way wall pointing against us — stop swinging.
	if level.rect_blocks_carve_px(pocket, lemming.direction):
		lemming.change_state(Lemming.State.WALKING)
		return
	var carved: int = level.carve_rect_px(pocket, lemming.direction)
	if carved == 0:
		lemming.change_state(Lemming.State.WALKING)
		return
	lemming.global_position += Vector2(lemming.direction * 4.0, 4.0)
