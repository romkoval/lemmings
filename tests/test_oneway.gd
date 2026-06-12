extends "res://addons/gut/test.gd"

# US-1.5: one-way walls. A wall carries an arrow direction; directional skills
# (basher, miner) can only cut it ALONG the arrow and stop against it, while
# direction-less destruction (digger, bomber blasts) goes straight through —
# classic semantics. The material survives the editor's PNG round-trip.

const LemmingScene: PackedScene = preload("res://entities/lemming.tscn")
const TEST_PATH: String = "user://custom_levels/_gut_oneway_level.json"


func after_each() -> void:
	LevelManager.delete_custom_level(TEST_PATH)
	GameManager.reset()


func _level() -> Level:
	var level: Level = (load("res://scenes/game/level.tscn") as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	return level


func _lem(level: Level, pos: Vector2, dir: int = 1) -> Lemming:
	var lem: Lemming = LemmingScene.instantiate()
	level.add_child(lem)
	autoqfree(lem)
	lem.global_position = pos
	lem.direction = dir
	return lem


# ── Terrain-core semantics ───────────────────────────────────────────────────

func test_directional_carve_respects_the_arrow() -> void:
	var level := _level()
	var wall := Rect2i(80, 400, 24, 64)
	level.fill_rect_px(wall, PixelTerrain.MAT_ONEWAY_R)
	assert_eq(level.oneway_dir_px(Vector2(85.5, 430.5)), 1, "right-arrow material readable")
	# Against the arrow: nothing carved, the carve is blocked.
	assert_true(level.rect_blocks_carve_px(wall, -1), "opposing carve is blocked")
	assert_eq(level.carve_rect_px(wall, -1), 0, "opposing carve removes nothing")
	assert_true(level.is_solid_px(Vector2(85.5, 430.5)), "wall intact")
	# Along the arrow: carves like dirt.
	assert_false(level.rect_blocks_carve_px(wall, 1), "carve along the arrow allowed")
	assert_gt(level.carve_rect_px(wall, 1), 0, "carve along the arrow works")
	assert_false(level.is_solid_px(Vector2(85.5, 430.5)), "wall gone")


func test_directionless_carve_goes_through() -> void:
	# dir = 0 (digger slabs, bomber craters) ignores one-way arrows.
	var level := _level()
	level.fill_rect_px(Rect2i(80, 400, 24, 64), PixelTerrain.MAT_ONEWAY_L)
	assert_gt(level.carve_rect_px(Rect2i(80, 400, 24, 64)), 0, "dir-less carve goes through")
	assert_false(level.is_solid_px(Vector2(85.5, 430.5)))


# ── Skills ───────────────────────────────────────────────────────────────────

func test_basher_stops_against_the_arrow_and_cuts_along_it() -> void:
	var level := _level()
	level.fill_rect_px(Rect2i(32, 464, 200, 16))                    # floor
	level.fill_rect_px(Rect2i(80, 400, 24, 64), PixelTerrain.MAT_ONEWAY_L)
	var lem := _lem(level, Vector2(60, 448), 1)                     # feet (68, 464), wall ahead
	assert_true(lem.assign_skill(BasherSkill.new()))
	for i in range(BasherSkill.TICKS_PER_SWING + 1):
		lem._process_skill(1.0 / 60.0)
	assert_eq(lem.current_state, Lemming.State.WALKING, "basher gave up against the arrow")
	assert_true(level.is_solid_px(Vector2(85.5, 455.5)), "wall intact")
	# Same wall, approached along its arrow — cuts like dirt. Feet at (110,464):
	# the first slice spans x 92..108, overlapping the wall's 92..104 columns.
	var lem2 := _lem(level, Vector2(102, 448), -1)
	assert_true(lem2.assign_skill(BasherSkill.new()))
	for i in range(BasherSkill.TICKS_PER_SWING + 1):
		lem2._process_skill(1.0 / 60.0)
	assert_eq(lem2.current_state, Lemming.State.BASHING, "still tunnelling")
	assert_false(level.is_solid_px(Vector2(95.5, 455.5)), "slice carved along the arrow")


func test_miner_respects_the_arrow() -> void:
	var level := _level()
	level.fill_rect_px(Rect2i(32, 464, 200, 48))                    # thick floor
	level.fill_rect_px(Rect2i(64, 464, 64, 48), PixelTerrain.MAT_ONEWAY_L)
	var lem := _lem(level, Vector2(60, 448), 1)                     # feet (68,464), mining right
	assert_true(lem.assign_skill(MinerSkill.new()))
	for i in range(MinerSkill.TICKS_PER_SWING + 1):
		lem._process_skill(1.0 / 60.0)
	assert_eq(lem.current_state, Lemming.State.WALKING, "miner gave up against the arrow")
	assert_true(level.is_solid_px(Vector2(75.5, 466.5)), "floor intact")


func test_digger_digs_straight_through_oneway() -> void:
	var level := _level()
	level.fill_rect_px(Rect2i(32, 464, 200, 48), PixelTerrain.MAT_ONEWAY_R)
	var lem := _lem(level, Vector2(92, 448), 1)                     # feet (100, 464)
	assert_true(lem.assign_skill(DiggerSkill.new()))
	for i in range(12):
		lem._process_skill(1.0 / 60.0)
	assert_false(level.is_solid_px(Vector2(100.5, 465.5)), "digger went through the arrows")


# ── Editor round-trip ────────────────────────────────────────────────────────

func test_editor_oneway_survives_png_round_trip() -> void:
	var editor = (load("res://scenes/editor/level_editor.tscn") as PackedScene).instantiate()
	add_child_autoqfree(editor)
	await wait_physics_frames(1)
	editor.tool = editor.Tool.ONEWAY_R
	editor._stroke_at(Vector2(100, 500))
	editor.tool = editor.Tool.ONEWAY_L
	editor._last_stroke = Vector2.INF
	editor._stroke_at(Vector2(300, 500))
	assert_eq(editor.terrain.oneway_dir_px(Vector2(100, 500)), 1, "right wall painted")
	assert_eq(editor.terrain.oneway_dir_px(Vector2(300, 500)), -1, "left wall painted")
	editor.level_id = "_gut_oneway_level"
	editor.save_path = TEST_PATH
	assert_true(editor._save(false))
	var base: PackedScene = load("res://levels/custom_base.tscn")
	var level: Level = base.instantiate() as Level
	level.set("data_path", TEST_PATH)
	add_child_autoqfree(level)
	await wait_physics_frames(2)
	assert_true(level.is_solid_px(Vector2(100, 500)), "wall solid in game")
	assert_eq(level.oneway_dir_px(Vector2(100, 500)), 1, "right arrow survived the PNG")
	assert_eq(level.oneway_dir_px(Vector2(300, 500)), -1, "left arrow survived the PNG")
