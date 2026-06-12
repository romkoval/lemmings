extends "res://addons/gut/test.gd"


func _validate_level_solvable(level_num: int, category: String = "fun") -> void:
	var data: Dictionary = LevelManager.load_level_data(category, level_num)
	assert_false(data.is_empty(), "level data must load")
	var save_required: int = int(data.get("save_required"))
	var total: int = int(data.get("total_lemmings"))
	var time_limit: int = int(data.get("time_limit"))
	assert_gt(total, 0, "level must have lemmings")
	assert_gt(time_limit, 0, "level must have a time limit")
	assert_lte(save_required, total, "save_required must not exceed total")
	# walk time at 60px/s across 720px max ≈ 12s/lemming; release rate gives spawn time
	var release_rate: int = int(data.get("release_rate", 50))
	var spawn_total_secs: float = float(total) * clampf(remap(release_rate, 1.0, 99.0, 3.0, 0.3), 0.3, 3.0)
	assert_gte(float(time_limit), spawn_total_secs, "time limit must allow all spawns")


func test_level_01_solvable() -> void:
	_validate_level_solvable(1)


func test_level_02_solvable() -> void:
	_validate_level_solvable(2)


func test_level_03_solvable() -> void:
	_validate_level_solvable(3)


func test_level_04_solvable() -> void:
	_validate_level_solvable(4)


func test_level_05_solvable() -> void:
	_validate_level_solvable(5)


func test_tricky_levels_statically_sane() -> void:
	# US-2.4: the tricky rank — 10 levels exercising the new objects. Static
	# sanity here; true solvability is proven by scripts/verify_levels.gd.
	for n in range(1, 11):
		_validate_level_solvable(n, "tricky")


func test_tricky_levels_use_new_objects() -> void:
	# Every tricky level must feature at least one of the new mechanics
	# (hazard zones, traps, one-way walls) or steel — that's the rank's brief.
	for n in range(1, 11):
		var data: Dictionary = LevelManager.load_level_data("tricky", n)
		var has_new: bool = not (data.get("hazards", []) as Array).is_empty() \
			or not (data.get("traps", []) as Array).is_empty() \
			or not (data.get("oneway_rects", []) as Array).is_empty() \
			or not (data.get("steel_rects", []) as Array).is_empty()
		assert_true(has_new, "tricky_%02d uses a new object" % n)


func test_save_manager_round_trip() -> void:
	SaveManager.mark_level_complete("test_xyz")
	assert_true(SaveManager.is_level_complete("test_xyz"))
	SaveManager.completed_levels.erase("test_xyz")
	SaveManager.save_progress()
