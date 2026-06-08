extends "res://addons/gut/test.gd"

const LemmingScene: PackedScene = preload("res://entities/lemming.tscn")
const LevelScene: PackedScene = preload("res://scenes/game/level.tscn")


var _level: Level
var _lemming: Lemming


func before_each() -> void:
	_level = LevelScene.instantiate()
	add_child_autoqfree(_level)
	_lemming = LemmingScene.instantiate()
	_level.add_child(_lemming)
	# Keep it tracked for cleanup but it's parented to the level, not the test.
	autoqfree(_lemming)


func _place_terrain(tile: Vector2i) -> void:
	_level.terrain_layer.set_cell(tile, 0, Vector2i.ZERO)


func test_can_step_up_with_one_tile_wall() -> void:
	# Floor under the lemming.
	_lemming.global_position = Vector2(80, 448)
	_lemming.direction = 1
	_place_terrain(Vector2i(5, 29))  # floor
	_place_terrain(Vector2i(6, 29))  # floor in front
	_place_terrain(Vector2i(6, 28))  # 1-tile wall in front at body level
	# Nothing above the wall.
	assert_true(_lemming.can_step_up())


func test_cannot_step_up_when_wall_is_taller() -> void:
	_lemming.global_position = Vector2(80, 448)
	_lemming.direction = 1
	_place_terrain(Vector2i(5, 29))
	_place_terrain(Vector2i(6, 29))
	_place_terrain(Vector2i(6, 28))  # wall at body level
	_place_terrain(Vector2i(6, 27))  # also blocked above
	assert_false(_lemming.can_step_up())


func test_cannot_step_up_when_no_wall_in_front() -> void:
	_lemming.global_position = Vector2(80, 448)
	_lemming.direction = 1
	_place_terrain(Vector2i(5, 29))
	# No tile at (6, 28).
	assert_false(_lemming.can_step_up())


func test_blocker_falls_when_undermined() -> void:
	# A blocker standing on a floor tile must drop to FALLING once that tile is
	# dug away beneath it (regression: it used to hang in mid-air).
	GameManager.set_state(GameManager.GameState.PLAYING)
	_lemming.global_position = Vector2(80, 448)
	_place_terrain(Vector2i(5, 29))
	_lemming.change_state(Lemming.State.BLOCKING)
	await wait_physics_frames(6)
	assert_eq(_lemming.current_state, Lemming.State.BLOCKING, "stays blocking while supported")
	_level.terrain_layer.erase_cell(Vector2i(5, 29))
	await wait_physics_frames(12)
	assert_eq(_lemming.current_state, Lemming.State.FALLING, "falls once undermined")
	GameManager.set_state(GameManager.GameState.MENU)


func test_builder_records_diagonal_start_tile() -> void:
	# Lemming standing on tile (5, 29) facing right.
	_lemming.global_position = Vector2(80, 448)
	_lemming.direction = 1
	_place_terrain(Vector2i(5, 29))
	var skill: BuilderSkill = BuilderSkill.new()
	skill.apply(_lemming)
	# First brick should go one tile forward at body level: (6, 28).
	assert_eq(skill._start_tile, Vector2i(6, 28))
	assert_eq(skill._start_dir, 1)


func test_builder_lays_diagonal_bricks() -> void:
	_lemming.global_position = Vector2(80, 448)
	_lemming.direction = 1
	_place_terrain(Vector2i(5, 29))
	var skill: BuilderSkill = BuilderSkill.new()
	skill.apply(_lemming)
	# First tick lays the plank, then the lemming walks up onto it over
	# TICKS_PER_STEP ticks — so one full step takes TICKS_PER_STEP + 1 ticks.
	for i in range(BuilderSkill.TICKS_PER_STEP + 1):
		skill.tick(_lemming)
	# After one step, the plank must exist at the start tile.
	var has_brick: bool = _level.terrain_layer.get_cell_source_id(Vector2i(6, 28)) != -1
	assert_true(has_brick, "plank should be placed at (6, 28)")
	assert_eq(skill.steps_placed, 1)
	# Lemming finished stepping one tile up + one tile forward onto the tread.
	assert_eq(int(_lemming.global_position.y), 28 * Level.TILE_SIZE - Level.TILE_SIZE)
	assert_eq(int(_lemming.global_position.x), 6 * Level.TILE_SIZE)


func test_builder_lays_connected_horizontal_blocks() -> void:
	# Each step lays a horizontal tread plank PLUS a fill plank one cell below, so
	# the 45° staircase reads as connected horizontal blocks (no gaps).
	_lemming.global_position = Vector2(80, 448)
	_lemming.direction = 1
	_place_terrain(Vector2i(5, 29))
	var skill: BuilderSkill = BuilderSkill.new()
	skill.apply(_lemming)
	for i in range((BuilderSkill.TICKS_PER_STEP + 1) * 2):
		skill.tick(_lemming)
	var layer := _level.terrain_layer
	# Step 0: tread (6,28) + fill (6,29).  Step 1: tread (7,27) + fill (7,28).
	assert_eq(layer.get_cell_atlas_coords(Vector2i(6, 28)), BuilderSkill.PLANK_ATLAS, "step 0 tread")
	assert_ne(layer.get_cell_source_id(Vector2i(6, 29)), -1, "step 0 fill")
	assert_eq(layer.get_cell_atlas_coords(Vector2i(7, 27)), BuilderSkill.PLANK_ATLAS, "step 1 tread")
	assert_ne(layer.get_cell_source_id(Vector2i(7, 28)), -1, "step 1 fill")


func test_digger_sinks_gradually() -> void:
	# The digger sinks a few px per tick and carves one block at a time, so blocks
	# don't vanish in an instant cascade.
	_lemming.global_position = Vector2(80, 448)
	_place_terrain(Vector2i(5, 29))
	_place_terrain(Vector2i(5, 30))
	_place_terrain(Vector2i(5, 31))
	var skill: DiggerSkill = DiggerSkill.new()
	skill.apply(_lemming)
	var y0: float = _lemming.global_position.y
	for i in range(4):
		skill.tick(_lemming)
	# Sank only ~4 ticks worth (a couple px), not a whole tile.
	assert_almost_eq(_lemming.global_position.y - y0, 4.0 * DiggerSkill.DIG_SPEED, 0.01)
	# Only the first block is carved; the ones below are still intact.
	assert_eq(_level.terrain_layer.get_cell_source_id(Vector2i(5, 29)), -1, "top block carved")
	assert_ne(_level.terrain_layer.get_cell_source_id(Vector2i(5, 30)), -1, "block below still intact")
