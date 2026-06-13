extends "res://addons/gut/test.gd"

# US-2.1: terrain visual themes. A theme is a palette preset pushed into the
# terrain shader (the four worlds of the original); physics is untouched. The
# theme is stored in the level JSON and round-trips editor -> game.

const TEST_PATH: String = "user://custom_levels/_gut_theme_level.json"


func after_each() -> void:
	LevelManager.delete_custom_level(TEST_PATH)
	GameManager.reset()


func test_set_theme_pushes_palette_into_the_shader() -> void:
	var terrain := PixelTerrain.new()
	add_child_autoqfree(terrain)
	terrain.build_blank(Rect2i(0, 0, 64, 64))
	terrain.set_theme("fire")
	var sh := terrain.material as ShaderMaterial
	var expected: Color = PixelTerrain.THEMES["fire"]["dirt_mid"]
	assert_eq(sh.get_shader_parameter("dirt_mid"), expected, "fire palette applied")
	terrain.set_theme("marble")
	assert_eq(sh.get_shader_parameter("dirt_mid"), PixelTerrain.THEMES["marble"]["dirt_mid"],
		"switching themes overwrites every palette uniform")
	terrain.set_theme("inferno")
	assert_eq(sh.get_shader_parameter("grass_hi"), PixelTerrain.THEMES["inferno"]["grass_hi"],
		"US-2.5: the hell palette is a first-class theme")


func test_unknown_theme_falls_back_to_dirt() -> void:
	var terrain := PixelTerrain.new()
	add_child_autoqfree(terrain)
	terrain.build_blank(Rect2i(0, 0, 64, 64))
	terrain.set_theme("no_such_world")
	assert_eq(terrain.theme_name, "dirt")


func test_theme_round_trips_editor_to_game() -> void:
	var editor = (load("res://scenes/editor/level_editor.tscn") as PackedScene).instantiate()
	add_child_autoqfree(editor)
	await wait_physics_frames(1)
	editor.tool = editor.Tool.DIRT
	editor._stroke_at(Vector2(100, 500))
	editor.theme_name = "crystal"
	editor.terrain.set_theme("crystal")
	editor.level_id = "_gut_theme_level"
	editor.save_path = TEST_PATH
	assert_true(editor._save(false))
	# Reopen in the editor: theme restored.
	var editor2 = (load("res://scenes/editor/level_editor.tscn") as PackedScene).instantiate()
	add_child_autoqfree(editor2)
	await wait_physics_frames(1)
	editor2._load_from(TEST_PATH)
	assert_eq(editor2.theme_name, "crystal", "editor reload restores the theme")
	assert_eq(editor2.terrain.theme_name, "crystal", "canvas repainted in the theme")
	# Play it: the level's terrain uses the theme.
	var base: PackedScene = load("res://levels/custom_base.tscn")
	var level: Level = base.instantiate() as Level
	level.set("data_path", TEST_PATH)
	add_child_autoqfree(level)
	await wait_physics_frames(2)
	assert_eq(level.terrain_theme, "crystal", "level reads the theme from JSON")
	assert_eq(level.pixel_terrain.theme_name, "crystal", "terrain built with the theme")
	var sh := level.pixel_terrain.material as ShaderMaterial
	assert_eq(sh.get_shader_parameter("grass_hi"), PixelTerrain.THEMES["crystal"]["grass_hi"],
		"shader palette matches the theme in game")
