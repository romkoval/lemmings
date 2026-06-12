extends "res://addons/gut/test.gd"

# US-1.3: death zones (water/fire). A lemming whose body enters a zone dies —
# floaters included (only the exit saves a lemming, never a hazard). Zones are
# authored in the editor as dragged-out rects, saved in the level JSON and
# rebuilt by ProceduralLevel.

const LemmingScene: PackedScene = preload("res://entities/lemming.tscn")
const TEST_PATH: String = "user://custom_levels/_gut_hazard_level.json"


func after_each() -> void:
	LevelManager.delete_custom_level(TEST_PATH)
	LevelManager.editing_path = ""
	GameManager.reset()


func _zone(parent: Node, type: HazardZone.HazardType, rect: Rect2) -> HazardZone:
	var z := HazardZone.new()
	z.hazard_type = type
	z.position = rect.position
	z.zone_size = rect.size
	parent.add_child(z)
	return z


func test_lemming_drowns_in_water() -> void:
	var level: Level = (load("res://scenes/game/level.tscn") as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	_zone(level, HazardZone.HazardType.WATER, Rect2(64, 448, 64, 32))
	var lem: Lemming = LemmingScene.instantiate()
	level.add_child(lem)
	lem.global_position = Vector2(80, 448)   # body capsule well inside the zone
	# die() frees the lemming the same frame — capture the signal, don't watch.
	var causes: Array = []
	lem.lemming_died.connect(func(_l, cause: String): causes.append(cause))
	await wait_physics_frames(3)
	assert_eq(causes, ["drowned"], "water kills, cause is drowning")


func test_floater_dies_in_fire_too() -> void:
	# A hazard ignores every protective skill — floaters burn like anyone else.
	var level: Level = (load("res://scenes/game/level.tscn") as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	_zone(level, HazardZone.HazardType.FIRE, Rect2(64, 448, 64, 32))
	var lem: Lemming = LemmingScene.instantiate()
	lem.is_floater = true
	level.add_child(lem)
	lem.global_position = Vector2(80, 448)
	var causes: Array = []
	lem.lemming_died.connect(func(_l, cause: String): causes.append(cause))
	await wait_physics_frames(3)
	assert_eq(causes, ["burned"], "floater is not spared, cause is burning")


func test_lemming_outside_zone_survives() -> void:
	var level: Level = (load("res://scenes/game/level.tscn") as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	_zone(level, HazardZone.HazardType.WATER, Rect2(64, 448, 64, 32))
	var lem: Lemming = LemmingScene.instantiate()
	level.add_child(lem)
	autoqfree(lem)
	lem.global_position = Vector2(200, 448)   # clear of the zone
	watch_signals(lem)
	await wait_physics_frames(3)
	assert_signal_not_emitted(lem, "lemming_died", "no false positives")


func test_editor_hazard_round_trips_through_game() -> void:
	# Drag a water rect in the editor, save, load through the real game
	# pipeline — the zone must come back at the same rect and still kill.
	var editor = (load("res://scenes/editor/level_editor.tscn") as PackedScene).instantiate()
	add_child_autoqfree(editor)
	await wait_physics_frames(1)
	editor.tool = editor.Tool.DIRT
	editor._stroke_at(Vector2(100, 500))   # some terrain so _save() accepts
	editor.tool = editor.Tool.WATER
	editor._last_stroke = Vector2.INF
	editor._stroke_at(Vector2(100, 600))   # press: anchor corner
	editor._stroke_at(Vector2(220, 660))   # drag: opposite corner
	editor._active_hazard = null           # release
	assert_eq(editor.hazards.size(), 1, "one zone created by the drag")
	var saved_rect: Rect2 = (editor.hazards[0] as HazardZone).rect_px()
	assert_eq(saved_rect, Rect2(100, 600, 120, 60), "rect spans the drag")
	editor.level_id = "_gut_hazard_level"
	editor.save_path = TEST_PATH
	assert_true(editor._save(false), "saves")
	# Reopen in the editor: the zone is restored as an editable object.
	var editor2 = (load("res://scenes/editor/level_editor.tscn") as PackedScene).instantiate()
	add_child_autoqfree(editor2)
	await wait_physics_frames(1)
	editor2._load_from(TEST_PATH)
	assert_eq(editor2.hazards.size(), 1, "editor reload restores the zone")
	assert_eq((editor2.hazards[0] as HazardZone).rect_px(), saved_rect)
	# Both editors share the test root, so their zones sit at the same global
	# coords as the played level's — free them before playing or the lemming
	# would drown once per overlapping Area2D.
	editor.queue_free()
	editor2.queue_free()
	await wait_physics_frames(1)
	# Play it: the zone exists in the level and kills a lemming inside it.
	var base: PackedScene = load("res://levels/custom_base.tscn")
	var level: Level = base.instantiate() as Level
	level.set("data_path", TEST_PATH)
	add_child_autoqfree(level)
	await wait_physics_frames(1)
	var zones: Array = []
	for n in get_tree().get_nodes_in_group("hazards"):
		if level.is_ancestor_of(n):
			zones.append(n)
	assert_eq(zones.size(), 1, "played level has the zone")
	assert_eq((zones[0] as HazardZone).rect_px(), saved_rect, "same rect in game")
	var lem: Lemming = LemmingScene.instantiate()
	level.add_child(lem)
	lem.global_position = Vector2(150, 620)
	var causes: Array = []
	lem.lemming_died.connect(func(_l, cause: String): causes.append(cause))
	await wait_physics_frames(3)
	assert_eq(causes, ["drowned"], "round-tripped zone still kills")


func test_editor_eraser_removes_hazard() -> void:
	var editor = (load("res://scenes/editor/level_editor.tscn") as PackedScene).instantiate()
	add_child_autoqfree(editor)
	await wait_physics_frames(1)
	editor.tool = editor.Tool.FIRE
	editor._last_stroke = Vector2.INF
	editor._stroke_at(Vector2(300, 700))
	editor._stroke_at(Vector2(400, 760))
	editor._active_hazard = null
	assert_eq(editor.hazards.size(), 1)
	editor.tool = editor.Tool.ERASE
	editor._last_stroke = Vector2.INF
	editor._stroke_at(Vector2(350, 730))   # inside the zone
	assert_eq(editor.hazards.size(), 0, "eraser deletes the whole zone")
