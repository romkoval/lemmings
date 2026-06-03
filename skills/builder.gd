class_name BuilderSkill
extends BaseSkill

const MAX_STEPS: int = 12
const TICKS_PER_STEP: int = 12

var steps_placed: int = 0
var tick_counter: int = 0
var _start_tile: Vector2i = Vector2i.ZERO
var _start_dir: int = 1


func get_skill_name() -> String:
	return "builder"


func can_apply(lemming: Lemming) -> bool:
	return lemming.current_state == Lemming.State.WALKING


func apply(lemming: Lemming) -> void:
	steps_placed = 0
	tick_counter = 0
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
	var tile: Vector2i = Vector2i(
		_start_tile.x + steps_placed * _start_dir,
		_start_tile.y - steps_placed
	)
	# Stop if a brick can't be placed (cell already occupied or off-map).
	# Builder bricks use the plain-dirt atlas tile (no grass on top).
	if not level.add_terrain_at(tile, 0, Vector2i(1, 0)):
		lemming.change_state(Lemming.State.WALKING)
		return
	# Step diagonally up onto the freshly-placed brick.
	lemming.global_position = Vector2(
		tile.x * Level.TILE_SIZE,
		tile.y * Level.TILE_SIZE - Level.TILE_SIZE
	)
	steps_placed += 1
	if steps_placed >= MAX_STEPS:
		lemming.change_state(Lemming.State.WALKING)
