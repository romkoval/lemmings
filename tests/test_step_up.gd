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


func _plank_sprite_count() -> int:
	var n: int = 0
	for c in _level.get_children():
		if c is Sprite2D and (c as Sprite2D).texture == BuilderSkill.PLANK_TEX:
			n += 1
	return n


func test_builder_builds_square_from_two_planks() -> void:
	# One 16×16 collision square is built from TWO plank movements; the collision
	# cell is stamped only once the second plank completes the square.
	_lemming.global_position = Vector2(80, 448)
	_lemming.direction = 1
	_place_terrain(Vector2i(5, 29))
	var skill: BuilderSkill = BuilderSkill.new()
	skill.apply(_lemming)
	# A few ticks lay the first (lower) plank. Its collision cell is stamped right
	# away so followers always have footing; the second plank only fills the top.
	for i in range(4):
		skill.tick(_lemming)
	assert_eq(skill.planks_laid, 1, "one plank laid")
	assert_eq(skill.steps_placed, 1, "collision stamped on the first plank")
	assert_eq(_level.terrain_layer.get_cell_atlas_coords(Vector2i(6, 28)), BuilderSkill.PLANK_ATLAS_R)
	assert_eq(_plank_sprite_count(), 1, "one plank sprite")
	# Run long enough to lay the second (visual) plank of the same square.
	for i in range(BuilderSkill.TICKS_PER_PLANK * 2 + 4):
		skill.tick(_lemming)
	assert_gte(skill.planks_laid, 2, "at least two planks laid")
	assert_gte(_plank_sprite_count(), 2, "second plank adds a sprite")


func test_builder_lays_separate_planks_no_fill() -> void:
	# Finished squares climb the 45° line; their collision cells sit one up + one
	# over with no fill cell between them, and every plank is its own sprite.
	_lemming.global_position = Vector2(80, 448)
	_lemming.direction = 1
	_place_terrain(Vector2i(5, 29))
	var skill: BuilderSkill = BuilderSkill.new()
	skill.apply(_lemming)
	for i in range(BuilderSkill.TICKS_PER_PLANK * 4 + 8):
		skill.tick(_lemming)
	var layer := _level.terrain_layer
	assert_eq(layer.get_cell_atlas_coords(Vector2i(6, 28)), BuilderSkill.PLANK_ATLAS_R, "square 0")
	assert_eq(layer.get_cell_atlas_coords(Vector2i(7, 27)), BuilderSkill.PLANK_ATLAS_R, "square 1")
	assert_eq(layer.get_cell_source_id(Vector2i(7, 28)), -1, "no fill below square 1")
	# A square's collision cell is stamped on its first (lower) plank, so squares
	# started == ceil(planks/2); one visible sprite per plank, no fill.
	assert_eq(skill.steps_placed, (skill.planks_laid + 1) / 2, "one collision cell per square started")
	assert_eq(_plank_sprite_count(), skill.planks_laid, "one sprite per plank")


func test_walker_unburies_when_terrain_stamped_on_it() -> void:
	# Regression: when one lemming builds a stair brick on top of another (or a
	# builder finishes inside foreign stairs), the buried body must climb out of
	# the solid tile instead of getting stuck in the texture.
	GameManager.set_state(GameManager.GameState.PLAYING)
	_lemming.global_position = Vector2(80, 448)  # origin at tile (5,28), feet on (5,29)
	_lemming.direction = 1
	_place_terrain(Vector2i(5, 29))              # floor under it
	await wait_physics_frames(4)                 # settle, WALKING
	assert_eq(_lemming.current_state, Lemming.State.WALKING, "walking on the floor")
	# Bury the body: stamp a solid tile right where the torso is.
	_place_terrain(Vector2i(5, 28))
	var y_before: float = _lemming.global_position.y
	await wait_physics_frames(8)
	# Lifted up onto the new tile, not embedded inside it.
	assert_lt(_lemming.global_position.y, y_before - 4.0, "climbed out of the buried tile")
	assert_false(_lemming._terrain_overlap(_lemming.global_position), "body no longer in solid")
	GameManager.set_state(GameManager.GameState.MENU)


func test_drilling_staircase_removes_plank_sprites() -> void:
	# Regression: plank sprites are decoupled from the collision tilemap. When a
	# built square is dug/bashed away, its planks must vanish with the tile —
	# otherwise the bridge stays visible but loses collision and lemmings fall
	# straight through it.
	_lemming.global_position = Vector2(80, 448)
	_lemming.direction = 1
	_place_terrain(Vector2i(5, 29))
	var skill: BuilderSkill = BuilderSkill.new()
	skill.apply(_lemming)
	# Lay a few squares of staircase.
	for i in range(BuilderSkill.TICKS_PER_PLANK * 4 + 8):
		skill.tick(_lemming)
	assert_gt(_plank_sprite_count(), 0, "staircase has plank sprites")
	# Square 0's collision cell is (6, 28); it carries 2 plank sprites.
	var before: int = _plank_sprite_count()
	assert_true(_level.is_solid_at(Vector2i(6, 28)), "square 0 is solid before drilling")
	# Drill a hole through square 0 (what a digger/basher does).
	var removed: bool = _level.remove_terrain_at(Vector2i(6, 28))
	await get_tree().process_frame   # let queue_free() take effect
	assert_true(removed, "tile removed")
	assert_false(_level.is_solid_at(Vector2i(6, 28)), "collision gone")
	assert_eq(_plank_sprite_count(), before - 2, "both planks of the drilled square removed")


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
