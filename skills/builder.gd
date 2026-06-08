class_name BuilderSkill
extends BaseSkill

const MAX_STEPS: int = 12
# Ticks per step. The lemming climbs for CLIMB_TICKS, then holds for the rest —
# a lay/step/pause rhythm so the bridge is laid deliberately (well under half the
# walking pace) instead of shooting up.
const TICKS_PER_STEP: int = 40
const CLIMB_TICKS: int = 20
# Step tile (tread + riser wedge, full-cell collision). One per step; the riser
# fills the gap to the previous step so the 45° run is one connected diagonal
# staircase. col 2 rises right, col 3 rises left — by build direction.
const PLANK_ATLAS_R: Vector2i = Vector2i(2, 1)
const PLANK_ATLAS_L: Vector2i = Vector2i(3, 1)

var steps_placed: int = 0
var _start_tile: Vector2i = Vector2i.ZERO
var _start_dir: int = 1
var _moving: bool = false
var _move_t: int = 0
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO


func get_skill_name() -> String:
	return "builder"


func can_apply(lemming: Lemming) -> bool:
	return lemming.current_state == Lemming.State.WALKING


func apply(lemming: Lemming) -> void:
	steps_placed = 0
	_moving = false
	_move_t = 0
	_start_dir = lemming.direction
	var level: Level = _get_level(lemming)
	if level != null:
		# Floor tile under the lemming's leading foot, then move up one row:
		# that's the empty cell at body level where the first plank goes.
		# Probe a couple px into the floor (+18, not +16) — the body settles ~1px
		# high, so feet+16 reads the empty cell above the floor and the staircase
		# would start a tile too high, leaving a gap followers can't climb.
		var feet_world: Vector2 = lemming.global_position + Vector2(8 + _start_dir * 8, 18)
		var floor_tile: Vector2i = level.world_to_tile(feet_world)
		_start_tile = floor_tile + Vector2i(0, -1)
	lemming.change_state(Lemming.State.BUILDING)


func plank_atlas() -> Vector2i:
	return PLANK_ATLAS_R if _start_dir > 0 else PLANK_ATLAS_L


# Tread cell for the Nth step — 45° staircase, one cell up + one cell over.
func _tile_for_step(n: int) -> Vector2i:
	return Vector2i(_start_tile.x + n * _start_dir, _start_tile.y - n)


# Bridge cell directly below step N. It shares its top edge with step N and its
# trailing edge with step N-1, so the diagonal corner gap between consecutive
# steps is filled and the staircase is a run of rectangular blocks touching
# edge-to-edge (the cell the player marked in red). None below step 0 — that one
# rests on the ground.
func _fill_for_step(n: int) -> Vector2i:
	return _tile_for_step(n) + Vector2i(0, 1)


func tick(lemming: Lemming) -> void:
	# Phase 1: stepping up onto the plank just laid, then holding for the rest of
	# the step (the pause that makes laying read as deliberate).
	if _moving:
		_move_t += 1
		var f: float = clampf(float(_move_t) / float(CLIMB_TICKS), 0.0, 1.0)
		lemming.global_position = _from.lerp(_to, f)
		if _move_t >= TICKS_PER_STEP:
			_moving = false
			if steps_placed >= MAX_STEPS:
				lemming.change_state(Lemming.State.WALKING)
		return
	# Phase 2: lay the next plank (+ a fill plank below to connect the steps),
	# then step onto it.
	if steps_placed >= MAX_STEPS:
		lemming.change_state(Lemming.State.WALKING)
		return
	var level: Level = _get_level(lemming)
	if level == null:
		lemming.change_state(Lemming.State.WALKING)
		return
	var tile: Vector2i = _tile_for_step(steps_placed)
	if not level.add_terrain_at(tile, 0, plank_atlas()):
		lemming.change_state(Lemming.State.WALKING)
		return
	# Bridge the corner gap to the step below so blocks meet edge-to-edge.
	if steps_placed > 0:
		level.add_terrain_at(_fill_for_step(steps_placed), 0, plank_atlas())
	_from = lemming.global_position
	_to = Vector2(
		tile.x * Level.TILE_SIZE,
		tile.y * Level.TILE_SIZE - Level.TILE_SIZE
	)
	_moving = true
	_move_t = 0
	steps_placed += 1
