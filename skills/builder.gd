class_name BuilderSkill
extends BaseSkill

const MAX_STEPS: int = 12
# Ticks to lay one plank AND walk up onto it. ~23 ticks (0.38s) ≈ the time it
# takes to walk the diagonal of one step at WALK_SPEED, so the lemming climbs
# each step exactly as fast as it's laid — no instant teleport that looks like
# the lemming is outrunning its own staircase.
const TICKS_PER_STEP: int = 23
# Builder steps are thin wooden planks (atlas col 2, row 1) instead of square
# dirt blocks. Collision is still a full cell (see main_tileset.tres).
const PLANK_ATLAS: Vector2i = Vector2i(2, 1)

var steps_placed: int = 0
var _start_tile: Vector2i = Vector2i.ZERO
var _start_dir: int = 1
# Smooth climb of the current step: slide from _from to _to over TICKS_PER_STEP.
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
		# that's the empty cell at body level where the first brick goes.
		# Probe a couple px into the floor (+18, not +16) — the body settles ~1px
		# high, so feet+16 reads the empty cell above the floor and the staircase
		# would start a tile too high, leaving a gap followers can't climb.
		var feet_world: Vector2 = lemming.global_position + Vector2(8 + _start_dir * 8, 18)
		var floor_tile: Vector2i = level.world_to_tile(feet_world)
		_start_tile = floor_tile + Vector2i(0, -1)
	lemming.change_state(Lemming.State.BUILDING)


func tick(lemming: Lemming) -> void:
	# Phase 1: walking up the step just laid. Slide smoothly so movement and
	# laying share the same pace.
	if _moving:
		_move_t += 1
		var f: float = clampf(float(_move_t) / float(TICKS_PER_STEP), 0.0, 1.0)
		lemming.global_position = _from.lerp(_to, f)
		if _move_t >= TICKS_PER_STEP:
			_moving = false
			if steps_placed >= MAX_STEPS:
				lemming.change_state(Lemming.State.WALKING)
		return
	# Phase 2: lay the next plank, then start walking onto it.
	if steps_placed >= MAX_STEPS:
		lemming.change_state(Lemming.State.WALKING)
		return
	var level: Level = _get_level(lemming)
	if level == null:
		lemming.change_state(Lemming.State.WALKING)
		return
	var tile: Vector2i = Vector2i(
		_start_tile.x + steps_placed * _start_dir,
		_start_tile.y - steps_placed
	)
	# Stop if a plank can't be placed (cell already occupied or off-map).
	if not level.add_terrain_at(tile, 0, PLANK_ATLAS):
		lemming.change_state(Lemming.State.WALKING)
		return
	_from = lemming.global_position
	_to = Vector2(
		tile.x * Level.TILE_SIZE,
		tile.y * Level.TILE_SIZE - Level.TILE_SIZE
	)
	_moving = true
	_move_t = 0
	steps_placed += 1
