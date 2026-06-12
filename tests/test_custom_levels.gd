extends "res://addons/gut/test.gd"

# Custom (player-made) level pipeline: JSON save/load round-trip through
# LevelManager, painted terrain_tiles applied by ProceduralLevel, and the
# custom_base scene playable from a user:// JSON exactly like a campaign level.

const TEST_PATH: String = "user://custom_levels/_gut_test_level.json"

const SAMPLE: Dictionary = {
	"id": "custom_gut",
	"name": "GUT уровень",
	"custom": true,
	"total_lemmings": 7,
	"save_required": 3,
	"time_limit": 120,
	"release_rate": 60,
	"skill_counts": {
		"climber": 1, "floater": 0, "bomber": 0, "blocker": 2,
		"builder": 3, "basher": 0, "miner": 0, "digger": 4,
	},
	"entrance_pos": [88.0, 88.0],
	"entrance_direction": 1,
	"exit_pos": [600.0, 424.0],
	# A floor run, one ramp, plus a steel block.
	"terrain_tiles": [[4, 29, 1, 0], [5, 29, 1, 0], [6, 29, 1, 0], [7, 28, 0, 1]],
	"steel": [[8, 29]],
}


func after_each() -> void:
	LevelManager.delete_custom_level(TEST_PATH)
	LevelManager.editing_path = ""


func test_json_round_trip() -> void:
	assert_true(LevelManager.save_level_json(TEST_PATH, SAMPLE), "saves")
	var loaded: Dictionary = LevelManager.load_level_json(TEST_PATH)
	assert_eq(str(loaded.get("name")), "GUT уровень")
	assert_eq(int(loaded.get("total_lemmings")), 7)
	assert_eq((loaded.get("terrain_tiles") as Array).size(), 4)
	var listed: Array = LevelManager.list_custom_levels()
	var ids: Array = listed.map(func(d): return d["id"])
	assert_has(ids, "custom_gut", "listed among custom levels")


func test_custom_level_loads_and_plays() -> void:
	LevelManager.save_level_json(TEST_PATH, SAMPLE)
	var base: PackedScene = load("res://levels/custom_base.tscn")
	var level: Level = base.instantiate() as Level
	level.set("data_path", TEST_PATH)
	add_child_autoqfree(level)
	await wait_physics_frames(2)
	# Params applied from JSON.
	assert_eq(level.total_lemmings, 7)
	assert_eq(level.save_required, 3)
	assert_eq(int(level.skill_counts.get("digger", 0)), 4)
	assert_eq(level.entrance.position, Vector2(88, 88))
	# Painted tiles rasterized into the pixel terrain: floor block solid…
	assert_true(level.is_solid_px(Vector2(5 * 16 + 8.5, 29 * 16 + 8.5)), "floor tile solid")
	# …ramp solid in its lower-right half, air in its upper-left…
	assert_true(level.is_solid_px(Vector2(7 * 16 + 13.5, 28 * 16 + 13.5)), "ramp lower half solid")
	assert_false(level.is_solid_px(Vector2(7 * 16 + 2.5, 28 * 16 + 2.5)), "ramp upper corner air")
	# …and steel is steel.
	assert_true(level.is_steel_px(Vector2(8 * 16 + 8.5, 29 * 16 + 8.5)), "steel block")


func test_delete_only_touches_custom_dir() -> void:
	LevelManager.save_level_json(TEST_PATH, SAMPLE)
	assert_true(FileAccess.file_exists(TEST_PATH))
	LevelManager.delete_custom_level(TEST_PATH)
	assert_false(FileAccess.file_exists(TEST_PATH), "custom file removed")
	# A path outside user://custom_levels/ must be refused.
	LevelManager.delete_custom_level("res://levels/fun/level_01.json")
	assert_true(FileAccess.file_exists("res://levels/fun/level_01.json"), "campaign files untouchable")


func test_editor_paints_pixels_and_round_trips_through_game() -> void:
	# The editor paints pixel brushes into a live PixelTerrain (WYSIWYG with the
	# game) and saves mask/material PNGs; the saved level must load back with
	# the same pixels solid — including steel — and the same parameters.
	var editor = (load("res://scenes/editor/level_editor.tscn") as PackedScene).instantiate()
	add_child_autoqfree(editor)
	await wait_physics_frames(1)
	editor.tool = editor.Tool.DIRT
	editor._stroke_at(Vector2(100, 500))
	editor._stroke_at(Vector2(160, 500))   # dirt band 100..160
	editor.tool = editor.Tool.STEEL
	editor._last_stroke = Vector2.INF
	editor._stroke_at(Vector2(300, 500))
	editor.tool = editor.Tool.EXIT
	editor._stroke_at(Vector2(600, 900))
	assert_true(editor.terrain.is_solid_px(Vector2(130, 500)), "dirt painted in editor mask")
	assert_true(editor.terrain.is_steel_px(Vector2(300, 500)), "steel painted in editor mask")
	# Save and reload through the real game pipeline.
	editor.level_id = "custom_gut_paint"
	editor.save_path = "user://custom_levels/custom_gut_paint.json"
	assert_true(editor._save(false), "saves PNGs + JSON")
	assert_true(FileAccess.file_exists("user://custom_levels/custom_gut_paint_mask.png"), "mask png written")
	var base: PackedScene = load("res://levels/custom_base.tscn")
	var level: Level = base.instantiate() as Level
	level.set("data_path", "user://custom_levels/custom_gut_paint.json")
	add_child_autoqfree(level)
	await wait_physics_frames(2)
	assert_true(level.is_solid_px(Vector2(130, 500)), "painted dirt solid in game")
	assert_false(level.is_solid_px(Vector2(130, 460)), "air above the stroke")
	assert_true(level.is_steel_px(Vector2(300, 500)), "painted steel is steel in game")
	assert_eq(level.level_exit.position, Vector2(600, 900), "exit where placed")
	LevelManager.delete_custom_level("user://custom_levels/custom_gut_paint.json")
	assert_false(FileAccess.file_exists("user://custom_levels/custom_gut_paint_mask.png"),
		"deleting the level removes its PNGs")


func test_wide_canvas_scrolls_and_round_trips() -> void:
	# A level can span several screens: painting beyond the first screen must
	# survive the save/load round-trip, the canvas resize must keep existing
	# strokes, and the played level must expose the full playfield to the
	# camera plus a kill plane below its bottom (not the hardcoded one-screen).
	var editor = (load("res://scenes/editor/level_editor.tscn") as PackedScene).instantiate()
	add_child_autoqfree(editor)
	await wait_physics_frames(1)
	editor.tool = editor.Tool.DIRT
	editor._stroke_at(Vector2(100, 500))
	editor._set_canvas_screens(2, 1)
	assert_true(editor.terrain.is_solid_px(Vector2(100, 500)), "resize keeps painted pixels")
	editor._last_stroke = Vector2.INF
	editor._stroke_at(Vector2(1100, 700))   # beyond the first screen
	assert_true(editor.terrain.is_solid_px(Vector2(1100, 700)), "painting past screen 1 works")
	editor.level_id = "custom_gut_wide"
	editor.save_path = "user://custom_levels/custom_gut_wide.json"
	assert_true(editor._save(false))
	var base: PackedScene = load("res://levels/custom_base.tscn")
	var level: Level = base.instantiate() as Level
	level.set("data_path", "user://custom_levels/custom_gut_wide.json")
	add_child_autoqfree(level)
	await wait_physics_frames(2)
	assert_true(level.is_solid_px(Vector2(1100, 700)), "off-screen stroke solid in game")
	var bounds: Rect2 = level.get_terrain_bounds_px()
	assert_gte(bounds.size.x, 1440.0, "camera can scroll the full two-screen width")
	assert_gt(level.kill_plane_y(), bounds.end.y, "kill plane below the playfield")
	LevelManager.delete_custom_level("user://custom_levels/custom_gut_wide.json")


func test_bounds_always_cover_entrance_and_exit() -> void:
	# Even when the terrain is a thin band, the scrollable area includes the
	# doors and at least one screen — the camera can always reach the action.
	var base: PackedScene = load("res://levels/custom_base.tscn")
	var level: Level = base.instantiate() as Level
	add_child_autoqfree(level)
	await wait_physics_frames(1)
	level.level_exit.position = Vector2(650, 1200)
	var bounds: Rect2 = level.get_terrain_bounds_px()
	assert_true(bounds.encloses(Rect2(0, 0, 720, 1280)), "at least one screen scrollable")
	assert_true(bounds.has_point(level.entrance.position), "entrance reachable")
	assert_true(bounds.has_point(Vector2(650, 1199)), "exit reachable")


func test_editor_eraser_cuts_through_steel() -> void:
	# Gameplay carving must never remove steel, but the EDITOR's eraser is the
	# author's tool — it erases anything.
	var editor = (load("res://scenes/editor/level_editor.tscn") as PackedScene).instantiate()
	add_child_autoqfree(editor)
	await wait_physics_frames(1)
	editor.tool = editor.Tool.STEEL
	editor._stroke_at(Vector2(200, 400))
	assert_true(editor.terrain.is_steel_px(Vector2(200, 400)))
	editor.tool = editor.Tool.ERASE
	editor._last_stroke = Vector2.INF
	editor._stroke_at(Vector2(200, 400))
	assert_false(editor.terrain.is_solid_px(Vector2(200, 400)), "editor eraser removes steel")
