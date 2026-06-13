extends "res://addons/gut/test.gd"

# US-3.6: the minimap reads the level's theme and shows relief + hazards rather
# than a single flat fill.

const TEST_PATH: String = "user://custom_levels/_gut_mm_level.json"
const MinimapScript: Script = preload("res://ui/minimap.gd")

const SAMPLE: Dictionary = {
	"id": "_gut_mm_level", "name": "mm gut", "custom": true,
	"total_lemmings": 1, "save_required": 1, "time_limit": 60, "release_rate": 50,
	"skill_counts": {"digger": 1},
	"entrance_pos": [80, 398], "entrance_direction": 1, "exit_pos": [620, 446],
	"terrain_rects": [{"x": 0, "y": 28, "w": 45, "h": 6}],
	"hazards": [{"type": "fire", "rect": [300, 430, 96, 32]}],
	"theme": "inferno",
}


func after_each() -> void:
	LevelManager.delete_custom_level(TEST_PATH)
	GameManager.reset()


func _level() -> Level:
	LevelManager.save_level_json(TEST_PATH, SAMPLE)
	var base: PackedScene = load("res://levels/custom_base.tscn")
	var level: Level = base.instantiate() as Level
	level.set("data_path", TEST_PATH)
	add_child_autoqfree(level)
	return level


func test_minimap_builds_a_textured_thumbnail() -> void:
	var level := _level()
	await wait_physics_frames(2)
	var mm := Panel.new()
	mm.set_script(MinimapScript)
	add_child_autoqfree(mm)
	mm.bind(level, null)
	await wait_physics_frames(1)
	assert_true(mm.visible, "minimap shows once bound to a level with terrain")
	assert_not_null(mm._thumb, "a thumbnail image was built")
	# Relief means more than one terrain colour is present (cap vs rock), not a
	# single solid fill.
	var img: Image = mm._thumb.get_image()
	var colours := {}
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.1:
				colours[c.to_rgba32()] = true
	assert_gt(colours.size(), 1, "terrain is shaded, not a flat slab")


func test_theme_palette_table_covers_the_biomes() -> void:
	for theme in ["dirt", "fire", "inferno", "marble", "crystal"]:
		assert_true(MinimapScript.THEME_COLS.has(theme), "%s has a minimap palette" % theme)
