extends "res://addons/gut/test.gd"


func test_loads_level_01() -> void:
	var data: Dictionary = LevelManager.load_level_data("fun", 1)
	assert_false(data.is_empty(), "level_01.json should parse")
	assert_eq(data.get("id"), "fun_01")
	assert_eq(int(data.get("save_required")), 8)
	assert_eq(int(data.get("total_lemmings")), 10)


func test_loads_all_fun_levels() -> void:
	for n in range(1, 6):
		var data: Dictionary = LevelManager.load_level_data("fun", n)
		assert_false(data.is_empty(), "level_%02d.json should parse" % n)
		assert_has(data, "skill_counts")
		assert_has(data, "entrance_pos")
		assert_has(data, "exit_pos")


func test_list_fun_levels() -> void:
	var files: Array = LevelManager.list_levels("fun")
	assert_eq(files.size(), 5)
	assert_eq(files[0], "level_01.json")


func test_missing_level_returns_empty() -> void:
	var data: Dictionary = LevelManager.load_level_data("fun", 99)
	assert_true(data.is_empty())


func test_scene_path_format() -> void:
	var path: String = LevelManager.get_scene_path("fun", 3)
	assert_eq(path, "res://levels/fun/level_03.tscn")
