extends "res://addons/gut/test.gd"

# US-4.1: one-file level sharing. Export bundles the JSON + terrain PNGs into
# a single .lemlvl (PNGs as base64); import unpacks it, never overwrites an
# existing level, and the result plays identically.

const TEST_PATH: String = "user://custom_levels/_gut_share_level.json"


func after_each() -> void:
	for f in ["_gut_share_level", "_gut_share_level_imp", "_gut_share_level_imp_imp"]:
		LevelManager.delete_custom_level("user://custom_levels/%s.json" % f)
	var p: String = "user://custom_levels/_gut_share_level.lemlvl"
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
	LevelManager.editing_path = ""
	GameManager.reset()


func _make_painted_level() -> void:
	var editor = (load("res://scenes/editor/level_editor.tscn") as PackedScene).instantiate()
	add_child(editor)
	editor.tool = editor.Tool.DIRT
	editor._stroke_at(Vector2(100, 500))
	editor._stroke_at(Vector2(200, 500))
	editor.level_id = "_gut_share_level"
	editor.level_name = "share gut"
	editor.save_path = TEST_PATH
	assert_true(editor._save(false))
	editor.queue_free()


func test_export_import_round_trip() -> void:
	_make_painted_level()
	await wait_physics_frames(1)
	var bundle: String = LevelManager.export_level(TEST_PATH)
	assert_ne(bundle, "", "export produced a bundle")
	assert_true(bundle.ends_with(".lemlvl"))
	# Import alongside the original: id collision resolved with a suffix.
	var imported: String = LevelManager.import_level(bundle)
	assert_ne(imported, "", "import succeeded")
	assert_ne(imported, TEST_PATH, "no overwrite of the existing level")
	var d: Dictionary = LevelManager.load_level_json(imported)
	assert_eq(str(d.get("name")), "share gut", "meta survived")
	assert_false(d.has("terrain_mask_b64"), "base64 unpacked, not kept")
	# The imported copy plays with the same pixels solid.
	var base: PackedScene = load("res://levels/custom_base.tscn")
	var level: Level = base.instantiate() as Level
	level.set("data_path", imported)
	add_child_autoqfree(level)
	await wait_physics_frames(2)
	assert_true(level.is_solid_px(Vector2(150, 500)), "painted stroke solid after the round trip")
	LevelManager.delete_custom_level(imported)
	DirAccess.remove_absolute(bundle)


func test_import_rejects_garbage() -> void:
	var p: String = "user://custom_levels/_gut_bad.lemlvl"
	DirAccess.make_dir_recursive_absolute("user://custom_levels/")
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string("{\"id\": \"x\"}")   # no name, no terrain
	f.close()
	assert_eq(LevelManager.import_level(p), "", "incomplete bundle refused")
	var f2 := FileAccess.open(p, FileAccess.WRITE)
	f2.store_string("not json at all")
	f2.close()
	assert_eq(LevelManager.import_level(p), "", "non-JSON refused")
	DirAccess.remove_absolute(p)
