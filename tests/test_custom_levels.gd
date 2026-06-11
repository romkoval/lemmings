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


func test_editor_scene_collects_painted_data() -> void:
	var editor = (load("res://scenes/editor/level_editor.tscn") as PackedScene).instantiate()
	add_child_autoqfree(editor)
	await wait_physics_frames(1)
	# Paint a few cells through the tool API.
	editor.tool = editor.Tool.DIRT
	editor._apply_tool(Vector2(4 * 16 + 8, 29 * 16 + 8))
	editor.tool = editor.Tool.STEEL
	editor._apply_tool(Vector2(6 * 16 + 8, 29 * 16 + 8))
	editor.tool = editor.Tool.EXIT
	editor._apply_tool(Vector2(20 * 16 + 8, 10 * 16 + 8))
	var d: Dictionary = editor._collect_data()
	assert_eq((d["terrain_tiles"] as Array).size(), 1, "one dirt cell")
	assert_eq((d["steel"] as Array).size(), 1, "one steel cell")
	assert_eq(d["exit_pos"], [20.0 * 16 + 8, 10.0 * 16 + 8])
	assert_true(str(d["id"]).begins_with("custom_"), "id generated")
