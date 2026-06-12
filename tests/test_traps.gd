extends "res://addons/gut/test.gd"

# US-1.4: triggered traps. An armed trap kills exactly the first lemming that
# steps into its trigger, then stays harmless through snap+cooldown (the crowd
# walks past), then re-arms and kills again. Traps are placed in the editor
# and round-trip through the level JSON.

const LemmingScene: PackedScene = preload("res://entities/lemming.tscn")
const TEST_PATH: String = "user://custom_levels/_gut_trap_level.json"

# SNAP + COOLDOWN in physics frames, plus margin.
const REARM_FRAMES: int = int((Trap.SNAP_TIME + Trap.COOLDOWN_TIME) * 60.0) + 10


func after_each() -> void:
	LevelManager.delete_custom_level(TEST_PATH)
	LevelManager.editing_path = ""
	GameManager.reset()
	GameManager.set_state(GameManager.GameState.MENU)


func _level_with_floor() -> Level:
	var level: Level = (load("res://scenes/game/level.tscn") as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	level.fill_rect_px(Rect2i(32, 464, 320, 32))   # floor at y=464
	return level


func _trap(parent: Node, at: Vector2, type: Trap.TrapType = Trap.TrapType.CRUSHER) -> Trap:
	var t := Trap.new()
	t.trap_type = type
	t.position = at
	parent.add_child(t)
	return t


func _lem(parent: Node, pos: Vector2) -> Lemming:
	var lem: Lemming = LemmingScene.instantiate()
	parent.add_child(lem)
	lem.global_position = pos
	return lem


func test_trap_kills_the_first_lemming_then_cools_down() -> void:
	var level := _level_with_floor()
	var trap := _trap(level, Vector2(96, 440))   # trigger 96..120 × 440..464, on the floor
	GameManager.set_state(GameManager.GameState.PLAYING)
	var causes: Array = []
	var a := _lem(level, Vector2(92, 448))       # body centre (100, 457.5) inside
	a.lemming_died.connect(func(_l, c: String): causes.append(c))
	await wait_physics_frames(3)
	assert_eq(causes, ["trapped"], "armed trap kills the first lemming")
	assert_ne(trap.phase, Trap.Phase.IDLE, "trap is busy after the kill")
	# A second lemming inside the trigger during snap/cooldown is unharmed.
	var b := _lem(level, Vector2(92, 448))
	autoqfree(b)
	var b_dead: Array = []
	b.lemming_died.connect(func(_l, c: String): b_dead.append(c))
	await wait_physics_frames(10)
	assert_eq(b_dead, [], "crowd passes while the trap resets")


func test_trap_rearms_and_kills_again() -> void:
	var level := _level_with_floor()
	var trap := _trap(level, Vector2(96, 440), Trap.TrapType.CLAMP)
	GameManager.set_state(GameManager.GameState.PLAYING)
	var a := _lem(level, Vector2(92, 448))
	await wait_physics_frames(3)
	await wait_physics_frames(REARM_FRAMES)
	assert_eq(trap.phase, Trap.Phase.IDLE, "trap re-armed after cooldown")
	var c := _lem(level, Vector2(92, 448))
	var c_dead: Array = []
	c.lemming_died.connect(func(_l, cause: String): c_dead.append(cause))
	await wait_physics_frames(3)
	assert_eq(c_dead, ["trapped"], "re-armed trap kills again")


func test_trap_is_inert_outside_playing() -> void:
	# Paused/menu: a lemming standing in the trigger must NOT die.
	var level := _level_with_floor()
	_trap(level, Vector2(96, 440))
	var a := _lem(level, Vector2(92, 448))
	autoqfree(a)
	var causes: Array = []
	a.lemming_died.connect(func(_l, c: String): causes.append(c))
	await wait_physics_frames(5)
	assert_eq(causes, [], "no kills while not PLAYING")


func test_editor_trap_round_trips_through_game() -> void:
	var editor = (load("res://scenes/editor/level_editor.tscn") as PackedScene).instantiate()
	add_child_autoqfree(editor)
	await wait_physics_frames(1)
	editor.tool = editor.Tool.DIRT
	editor._stroke_at(Vector2(100, 500))
	editor.tool = editor.Tool.TRAP_CLAMP
	editor._last_stroke = Vector2.INF
	editor._stroke_at(Vector2(300, 700))
	editor._active_trap = null
	assert_eq(editor.traps.size(), 1, "tap places one trap")
	var placed: Vector2 = (editor.traps[0] as Trap).position
	assert_eq(placed, (Vector2(300, 700) - Trap.TRIGGER_SIZE * 0.5).round(), "centred under the tap")
	editor.level_id = "_gut_trap_level"
	editor.save_path = TEST_PATH
	assert_true(editor._save(false))
	# Reopen in the editor.
	var editor2 = (load("res://scenes/editor/level_editor.tscn") as PackedScene).instantiate()
	add_child_autoqfree(editor2)
	await wait_physics_frames(1)
	editor2._load_from(TEST_PATH)
	assert_eq(editor2.traps.size(), 1, "editor reload restores the trap")
	assert_eq((editor2.traps[0] as Trap).trap_type, Trap.TrapType.CLAMP, "type survives")
	editor.queue_free()
	editor2.queue_free()
	await wait_physics_frames(1)
	# Play it.
	var base: PackedScene = load("res://levels/custom_base.tscn")
	var level: Level = base.instantiate() as Level
	level.set("data_path", TEST_PATH)
	add_child_autoqfree(level)
	await wait_physics_frames(1)
	var in_level: Array = []
	for n in get_tree().get_nodes_in_group("traps"):
		if level.is_ancestor_of(n):
			in_level.append(n)
	assert_eq(in_level.size(), 1, "played level has the trap")
	assert_eq((in_level[0] as Trap).position, placed, "same position in game")


func test_editor_eraser_removes_trap() -> void:
	var editor = (load("res://scenes/editor/level_editor.tscn") as PackedScene).instantiate()
	add_child_autoqfree(editor)
	await wait_physics_frames(1)
	editor.tool = editor.Tool.TRAP_CRUSHER
	editor._last_stroke = Vector2.INF
	editor._stroke_at(Vector2(300, 700))
	editor._active_trap = null
	assert_eq(editor.traps.size(), 1)
	editor.tool = editor.Tool.ERASE
	editor._last_stroke = Vector2.INF
	editor._stroke_at(Vector2(300, 700))
	assert_eq(editor.traps.size(), 0, "eraser deletes the trap")
