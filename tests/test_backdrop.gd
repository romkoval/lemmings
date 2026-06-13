extends "res://addons/gut/test.gd"

# US-2.7: themed level backgrounds. Surface (dirt) levels get a scenic
# BiomeBackdrop (sky/mountains/trees); stony themes get the cave variant; the
# inferno keeps its original dark starfield (no BiomeBackdrop).

const TEST_PATH: String = "user://custom_levels/_gut_bg_level.json"

const SAMPLE: Dictionary = {
	"id": "_gut_bg_level", "name": "bg gut", "custom": true,
	"total_lemmings": 1, "save_required": 1, "time_limit": 60, "release_rate": 50,
	"skill_counts": {"digger": 1},
	"entrance_pos": [80, 398], "entrance_direction": 1, "exit_pos": [620, 446],
	"terrain_rects": [{"x": 0, "y": 29, "w": 45, "h": 4}],
}


func after_each() -> void:
	LevelManager.delete_custom_level(TEST_PATH)
	GameManager.reset()


func _level_with_theme(theme: String) -> Level:
	var d: Dictionary = SAMPLE.duplicate(true)
	d["theme"] = theme
	LevelManager.save_level_json(TEST_PATH, d)
	var base: PackedScene = load("res://levels/custom_base.tscn")
	var level: Level = base.instantiate() as Level
	level.set("data_path", TEST_PATH)
	add_child_autoqfree(level)
	return level


func _find_backdrop(level: Level) -> BiomeBackdrop:
	var bg := level.get_node_or_null("Background")
	if bg == null:
		return null
	for c in bg.get_children():
		if c is BiomeBackdrop:
			return c
	return null


func test_dirt_level_gets_the_surface_backdrop() -> void:
	var level := _level_with_theme("dirt")
	await wait_physics_frames(2)
	var bd := _find_backdrop(level)
	assert_not_null(bd, "surface levels get a scenic backdrop")
	assert_eq(bd.biome, "grass", "dirt → grassy surface")


func test_crystal_level_gets_the_cave_backdrop() -> void:
	var level := _level_with_theme("crystal")
	await wait_physics_frames(2)
	var bd := _find_backdrop(level)
	assert_not_null(bd)
	assert_eq(bd.biome, "cave", "stony themes → cave backdrop")


func test_inferno_keeps_the_dark_background() -> void:
	var level := _level_with_theme("inferno")
	await wait_physics_frames(2)
	assert_null(_find_backdrop(level), "inferno uses no scenic backdrop")
	var bg := level.get_node_or_null("Background")
	assert_not_null(bg, "but it still has the dark background layer")
	var has_color := false
	for c in bg.get_children():
		if c is ColorRect:
			has_color = true
	assert_true(has_color, "the original dark fill is kept for the inferno")
