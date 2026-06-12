class_name BasherSkill
extends BaseSkill

# Bashes a horizontal tunnel through pixel terrain: every swing carves a 16px
# deep slice ahead (full body height, floor preserved), then the basher walks
# smoothly into the cleared space over the rest of the cycle. 16px per 24 ticks
# ≈ 40 px/s — deliberately slower than the 60 px/s walk.

const TICKS_PER_SWING: int = 24
const SLICE_DEPTH: int = 16
const TUNNEL_H: int = 17        # rows feet-17..feet-1; the floor row stays

var tick_counter: int = 0
var _advance_budget: float = 0.0


func get_skill_name() -> String:
	return "basher"


func can_apply(lemming: Lemming) -> bool:
	return lemming.current_state == Lemming.State.WALKING


func needs_tick() -> bool:
	return true


func apply(lemming: Lemming) -> void:
	tick_counter = 0
	_advance_budget = 0.0
	lemming.change_state(Lemming.State.BASHING)


func tick(lemming: Lemming) -> void:
	var level: Level = _get_level(lemming)
	if level == null:
		lemming.change_state(Lemming.State.WALKING)
		return
	# Walk into the space cleared by the last swing, hugging the tunnel floor.
	if _advance_budget > 0.0:
		var step: float = minf(float(SLICE_DEPTH) / float(TICKS_PER_SWING), _advance_budget)
		_advance_budget -= step
		lemming.global_position.x += lemming.direction * step
		_settle_on_floor(lemming, level)
	tick_counter += 1
	if tick_counter < TICKS_PER_SWING:
		return
	tick_counter = 0
	var fx: int = lemming.feet_x()
	var fy: int = lemming.feet_y()
	var x0: int = fx + 2 if lemming.direction > 0 else fx - 2 - SLICE_DEPTH
	var slice := Rect2i(x0, fy - TUNNEL_H, SLICE_DEPTH, TUNNEL_H)
	if level.rect_has_steel_px(slice):
		lemming.change_state(Lemming.State.WALKING)
		return
	var carved: int = level.carve_rect_px(slice)
	if carved == 0:
		# Nothing solid ahead — tunnel finished, resume walking.
		lemming.change_state(Lemming.State.WALKING)
		return
	_advance_budget = float(SLICE_DEPTH)


# Keep the feet on the tunnel floor while advancing: pop over ≤2px bumps, drop
# onto ≤2px dips; deeper means the floor was dug away — fall.
func _settle_on_floor(lemming: Lemming, level: Level) -> void:
	var fx: int = lemming.feet_x()
	var fy: int = lemming.feet_y()
	if level.is_solid_px(Vector2(fx + 0.5, fy - 0.5)):
		for up in range(1, 3):
			if not level.is_solid_px(Vector2(fx + 0.5, fy - up - 0.5)):
				lemming.global_position.y -= up
				return
		return
	if level.is_solid_px(Vector2(fx + 0.5, fy + 0.5)):
		return
	for dn in range(1, 3):
		if level.is_solid_px(Vector2(fx + 0.5, fy + dn + 0.5)):
			lemming.global_position.y += dn
			return
	lemming.change_state(Lemming.State.FALLING)
