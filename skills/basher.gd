class_name BasherSkill
extends BaseSkill

# 16px every 24 ticks ≈ 40 px/s — deliberately slower than the 60 px/s walk speed
# (the original bashes at a steady, unhurried pace, not a blur).
const TICKS_PER_DIG: int = 24


var tick_counter: int = 0


func get_skill_name() -> String:
	return "basher"


func can_apply(lemming: Lemming) -> bool:
	return lemming.current_state == Lemming.State.WALKING


func apply(lemming: Lemming) -> void:
	tick_counter = 0
	lemming.change_state(Lemming.State.BASHING)


func tick(lemming: Lemming) -> void:
	tick_counter += 1
	if tick_counter < TICKS_PER_DIG:
		return
	tick_counter = 0
	var level: Level = _get_level(lemming)
	if level == null:
		lemming.change_state(Lemming.State.WALKING)
		return
	# Tile just past the body's leading edge at body height (origin + 8 ± to the
	# front of the box). A shorter reach falls inside the lemming's own cell and
	# bails out immediately.
	var target: Vector2i = level.world_to_tile(
		lemming.global_position + Vector2(8 + lemming.direction * 8, 8))
	if level.is_steel_at(target):
		lemming.change_state(Lemming.State.WALKING)
		return
	if not level.remove_terrain_at(target):
		# Nothing solid ahead — tunnel finished, resume walking.
		lemming.change_state(Lemming.State.WALKING)
		return
	# Also clear the tile ABOVE the body row so the tunnel is tall enough to walk
	# through. A lemming settles ~1px high, so its capsule top pokes 1px into the
	# row above the body tile; clearing only one row leaves that sliver solid and
	# the crowd is blocked at the tunnel mouth. Best-effort (no-op if open above).
	level.remove_terrain_at(target + Vector2i(0, -1))
	# Step a full tile into the cleared cell so the next probe lines up.
	lemming.global_position.x += lemming.direction * Level.TILE_SIZE
