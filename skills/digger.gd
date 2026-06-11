class_name DiggerSkill
extends BaseSkill

# Digs a vertical shaft straight down, pixel-style: each tick the digger sinks
# a fraction of a pixel and carves a thin slab of ground out from under its
# feet across the shaft width, so the ground crumbles gradually instead of
# whole blocks vanishing at once.

# Descent in px per physics tick. 0.5px ≈ 30 px/s — half walking speed.
const DIG_SPEED: float = 0.5
const SHAFT_HALF_W: int = 7   # 14px wide shaft, a body's width plus margin


func get_skill_name() -> String:
	return "digger"


func can_apply(lemming: Lemming) -> bool:
	return lemming.current_state == Lemming.State.WALKING


func apply(lemming: Lemming) -> void:
	lemming.change_state(Lemming.State.DIGGING)


func tick(lemming: Lemming) -> void:
	var level: Level = _get_level(lemming)
	if level == null:
		lemming.change_state(Lemming.State.WALKING)
		return
	var fx: int = lemming.feet_x()
	var fy: int = lemming.feet_y()
	# Steel right under the feet stops the dig.
	if level.is_steel_px(Vector2(fx + 0.5, fy + 1.5)):
		lemming.change_state(Lemming.State.WALKING)
		return
	# Carve a 2px slab at foot level across the shaft, then sink into it. The
	# same slab feeds several ticks of fractional descent, so carved == 0 is
	# normal mid-block — only running out of ground below ends the dig.
	level.carve_rect_px(Rect2i(fx - SHAFT_HALF_W, fy, SHAFT_HALF_W * 2, 2))
	var open_below: bool = true
	for dy in range(1, 5):
		if level.is_solid_px(Vector2(fx + 0.5, fy + dy + 0.5)):
			open_below = false
			break
	if open_below:
		# Broke through the bottom — fall into the shaft.
		lemming.change_state(Lemming.State.FALLING)
		return
	lemming.global_position.y += DIG_SPEED
