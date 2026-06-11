extends "res://addons/gut/test.gd"

# Pixel-terrain movement and building behaviors: walkers mount small steps and
# turn at walls, blockers fall when undermined, buried lemmings climb out, the
# builder lays real wood pixels, the digger sinks gradually.

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


func after_each() -> void:
	GameManager.set_state(GameManager.GameState.MENU)


# Fill one 16×16 block of dirt at tile coords (authoring helper).
func _place_block(tile: Vector2i) -> void:
	_level.fill_rect_px(Rect2i(tile * Level.TILE_SIZE, Vector2i(Level.TILE_SIZE, Level.TILE_SIZE)))


func _floor_run(from_x: int, to_x: int, row: int = 29) -> void:
	for x in range(from_x, to_x + 1):
		_place_block(Vector2i(x, row))


# ── Walking over steps and walls ─────────────────────────────────────────────

func test_walker_mounts_8px_step() -> void:
	GameManager.set_state(GameManager.GameState.PLAYING)
	_lemming.global_position = Vector2(80, 448)   # feet (88, 464)
	_lemming.direction = 1
	_floor_run(4, 9)
	# An 8px-tall slab on the floor ahead (a builder plank): rows 456..463.
	_level.fill_rect_px(Rect2i(96, 456, 16, 8), PixelTerrain.MAT_WOOD)
	await wait_physics_frames(20)
	assert_eq(_lemming.current_state, Lemming.State.WALKING, "still walking")
	assert_eq(_lemming.feet_y(), 456, "mounted the 8px step")
	assert_gt(_lemming.feet_x(), 96, "kept moving forward")


func test_walker_turns_at_tall_wall() -> void:
	GameManager.set_state(GameManager.GameState.PLAYING)
	_lemming.global_position = Vector2(80, 448)
	_lemming.direction = 1
	_floor_run(4, 9)
	_place_block(Vector2i(6, 28))   # 16px wall on the floor ahead (rise > 8)
	await wait_physics_frames(20)
	assert_eq(_lemming.direction, -1, "turned around at the wall")
	assert_eq(_lemming.current_state, Lemming.State.WALKING)


func test_walker_falls_off_edge() -> void:
	GameManager.set_state(GameManager.GameState.PLAYING)
	_lemming.global_position = Vector2(80, 448)
	_lemming.direction = 1
	_place_block(Vector2i(5, 29))   # single block, edge right ahead
	await wait_physics_frames(20)
	assert_eq(_lemming.current_state, Lemming.State.FALLING, "walked off the edge")


func test_climber_scales_wall_and_mantles() -> void:
	GameManager.set_state(GameManager.GameState.PLAYING)
	_lemming.global_position = Vector2(80, 448)
	_lemming.direction = 1
	_lemming.is_climber = true
	_floor_run(4, 10)
	# 48px-tall wall, several tiles thick so the mantled walker has somewhere
	# to stand while we assert.
	for tx in range(7, 11):
		for ty in range(26, 29):
			_place_block(Vector2i(tx, ty))
	await wait_physics_frames(40)
	assert_eq(_lemming.current_state, Lemming.State.CLIMBING, "climbing the wall")
	await wait_physics_frames(120)
	assert_eq(_lemming.current_state, Lemming.State.WALKING, "mantled over the top")
	assert_lte(_lemming.feet_y(), 26 * 16, "standing on top of the wall")


# ── Blockers and burial ──────────────────────────────────────────────────────

func test_blocker_falls_when_undermined() -> void:
	# A blocker standing on a block must drop to FALLING once that block is
	# carved away beneath it (regression: it used to hang in mid-air).
	GameManager.set_state(GameManager.GameState.PLAYING)
	_lemming.global_position = Vector2(80, 448)
	_place_block(Vector2i(5, 29))
	_lemming.change_state(Lemming.State.BLOCKING)
	await wait_physics_frames(6)
	assert_eq(_lemming.current_state, Lemming.State.BLOCKING, "stays blocking while supported")
	_level.carve_rect_px(Rect2i(5 * 16, 29 * 16, 16, 16))
	await wait_physics_frames(12)
	assert_eq(_lemming.current_state, Lemming.State.FALLING, "falls once undermined")


func test_walker_unburies_when_terrain_stamped_on_it() -> void:
	# When terrain is built right on top of a lemming (another's stair plank),
	# the buried body must climb out of the solid instead of sticking inside.
	GameManager.set_state(GameManager.GameState.PLAYING)
	_lemming.global_position = Vector2(80, 448)   # feet (88, 464)
	_lemming.direction = 1
	_floor_run(4, 7)
	await wait_physics_frames(4)
	assert_eq(_lemming.current_state, Lemming.State.WALKING, "walking on the floor")
	# Bury the body: stamp a solid block exactly over the torso (pixel-aligned
	# on the current feet so the burial is guaranteed regardless of walk phase).
	_level.fill_rect_px(Rect2i(_lemming.feet_x() - 8, 448, 16, 16))
	var y_before: float = _lemming.global_position.y
	# Sample right after the un-bury: a few frames later the walker crosses the
	# 16px block and steps off its far side back to the floor (by design).
	await wait_physics_frames(4)
	assert_lt(_lemming.global_position.y, y_before - 4.0, "climbed out of the buried block")
	var fx: int = _lemming.feet_x()
	var fy: int = _lemming.feet_y()
	assert_false(_level.is_solid_px(Vector2(fx + 0.5, fy - 3.5)), "torso no longer inside solid")


# ── Builder ──────────────────────────────────────────────────────────────────

func test_builder_lays_planks_into_terrain() -> void:
	_lemming.global_position = Vector2(80, 448)   # feet (88, 464)
	_lemming.direction = 1
	_floor_run(4, 6)
	var skill: BuilderSkill = BuilderSkill.new()
	skill.apply(_lemming)
	assert_eq(_lemming.current_state, Lemming.State.BUILDING)
	# First tick lays plank 0 resting on the floor at the feet.
	skill.tick(_lemming)
	assert_eq(skill.planks_laid, 1, "first plank laid")
	assert_true(_level.is_solid_px(Vector2(96.5, 460.5)), "plank 0 is solid terrain")
	assert_false(_level.is_steel_px(Vector2(96.5, 460.5)), "plank is wood, not steel")
	assert_false(_level.is_solid_px(Vector2(96.5, 450.5)), "air above plank 0")
	# Run the full build: each plank is offset half a plank up and forward.
	for i in range(BuilderSkill.TICKS_PER_PLANK * 4 + 4):
		skill.tick(_lemming)
	assert_gte(skill.planks_laid, 4, "staircase keeps growing")
	var r1: Rect2i = skill.plank_rect(1)
	assert_true(_level.is_solid_px(Vector2(r1.get_center()) + Vector2(0.5, 0.5)), "plank 1 solid")
	assert_eq(r1.position, skill.plank_rect(0).position + Vector2i(8, -8), "8px up-forward offset")


func test_drilled_staircase_is_gone_for_real() -> void:
	# Planks are terrain pixels: carving them removes BOTH visual and collision
	# by construction — a ghost staircase cannot exist.
	_lemming.global_position = Vector2(80, 448)
	_lemming.direction = 1
	_floor_run(4, 6)
	var skill: BuilderSkill = BuilderSkill.new()
	skill.apply(_lemming)
	for i in range(BuilderSkill.TICKS_PER_PLANK * 2 + 4):
		skill.tick(_lemming)
	var r0: Rect2i = skill.plank_rect(0)
	var probe := Vector2(r0.get_center()) + Vector2(0.5, 0.5)
	assert_true(_level.is_solid_px(probe), "plank solid before drilling")
	var carved: int = _level.carve_rect_px(r0)
	assert_gt(carved, 0, "wood is carvable")
	assert_false(_level.is_solid_px(probe), "plank gone after drilling")


# ── Digger ───────────────────────────────────────────────────────────────────

func test_digger_sinks_gradually() -> void:
	# The digger sinks a fraction of a px per tick and carves thin slabs, so the
	# ground crumbles gradually instead of whole blocks vanishing at once.
	_lemming.global_position = Vector2(80, 448)   # feet (88, 464)
	_floor_run(5, 5)                              # block at (5,29)
	_place_block(Vector2i(5, 30))
	_place_block(Vector2i(5, 31))
	var skill: DiggerSkill = DiggerSkill.new()
	skill.apply(_lemming)
	var y0: float = _lemming.global_position.y
	for i in range(4):
		skill.tick(_lemming)
	assert_almost_eq(_lemming.global_position.y - y0, 4.0 * DiggerSkill.DIG_SPEED, 0.01)
	# Only a thin slab at the feet is carved; deeper rows are intact.
	assert_false(_level.is_solid_px(Vector2(88.5, 464.5)), "surface slab carved")
	assert_true(_level.is_solid_px(Vector2(88.5, 475.5)), "deeper ground still intact")
	assert_true(_level.is_solid_px(Vector2(88.5, 500.5)), "block below untouched")


func test_digger_stopped_by_steel() -> void:
	_lemming.global_position = Vector2(80, 448)
	_level.fill_rect_px(Rect2i(80, 464, 16, 16), PixelTerrain.MAT_STEEL)
	var skill: DiggerSkill = DiggerSkill.new()
	skill.apply(_lemming)
	skill.tick(_lemming)
	assert_eq(_lemming.current_state, Lemming.State.WALKING, "steel stops the dig")
	assert_true(_level.is_solid_px(Vector2(88.5, 464.5)), "steel intact")
