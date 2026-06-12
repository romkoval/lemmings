extends "res://addons/gut/test.gd"

# US-3.1/3.2/4.2: replays. Player actions are logged against the simulation
# tick; playback re-applies them on the same ticks (the pixel sim is
# deterministic). Winning a test-play from the editor stamps the level
# "verified" — the author's run is the proof of solvability.

const TEST_LEVEL: String = "user://custom_levels/_gut_replay_level.json"

const SAMPLE: Dictionary = {
	"id": "_gut_replay_level", "name": "replay gut", "custom": true,
	"total_lemmings": 3, "save_required": 1, "time_limit": 120, "release_rate": 50,
	"skill_counts": {"climber": 0, "floater": 0, "bomber": 0, "blocker": 0,
		"builder": 0, "basher": 0, "miner": 0, "digger": 5},
	"entrance_pos": [80, 398], "entrance_direction": 1, "exit_pos": [620, 446],
	"terrain_rects": [{"x": 0, "y": 29, "w": 45, "h": 4}],
}


func after_each() -> void:
	LevelManager.delete_custom_level(TEST_LEVEL)
	LevelManager.editing_path = ""
	GameManager.reset()


func _game(replay: Array = []) -> Game:
	LevelManager.save_level_json(TEST_LEVEL, SAMPLE)
	var game: Game = (load("res://scenes/game/game.tscn") as PackedScene).instantiate() as Game
	game.initial_level_path = TEST_LEVEL
	add_child_autoqfree(game)
	if not replay.is_empty():
		game.load_level(TEST_LEVEL, replay)
	return game


func test_sim_tick_advances_only_while_playing() -> void:
	GameManager.start_level("t", 1)
	await wait_physics_frames(3)
	var at: int = GameManager.sim_tick
	assert_gt(at, 0, "ticks while playing")
	GameManager.set_state(GameManager.GameState.MENU)
	await wait_physics_frames(3)
	assert_eq(GameManager.sim_tick, at, "frozen outside PLAYING")
	GameManager.reset()
	assert_eq(GameManager.sim_tick, 0, "reset zeroes the clock")


func test_assignments_are_recorded_with_tick_and_id() -> void:
	var game := _game()
	await wait_physics_frames(40)   # first lemming spawns and lands
	var lem: Lemming = get_tree().get_nodes_in_group("lemmings")[0] as Lemming
	assert_true(game.skill_manager.select_skill("digger"))
	assert_true(game.skill_manager.assign_to(lem))
	assert_eq(game.replay_log.size(), 1, "one event logged")
	var e: Dictionary = game.replay_log[0]
	assert_eq(str(e["type"]), "assign")
	assert_eq(str(e["skill"]), "digger")
	assert_eq(int(e["id"]), lem.lemming_id)
	assert_eq(int(e["t"]), GameManager.sim_tick, "stamped with the current tick")


func test_playback_applies_events_on_their_ticks() -> void:
	var replay: Array = [
		{"t": 10, "type": "rate", "v": 95},
		{"t": 40, "type": "assign", "skill": "digger", "id": 0},
	]
	var game := _game(replay)
	assert_true(game.replay_mode)
	await wait_physics_frames(60)
	assert_eq(game.current_level.entrance.release_rate, 95, "rate event applied")
	var lem0: Lemming = null
	for n in get_tree().get_nodes_in_group("lemmings"):
		if (n as Lemming).lemming_id == 0:
			lem0 = n as Lemming
	assert_not_null(lem0, "lemming 0 alive")
	assert_eq(lem0.current_state, Lemming.State.DIGGING, "assign event applied to the right lemming")
	assert_eq(game.replay_log.size(), 0, "watching records nothing")


func test_replay_round_trips_through_disk() -> void:
	var events: Array = [{"t": 5, "type": "nuke"}]
	assert_true(LevelManager.save_replay("_gut_replay_level", events))
	var loaded: Array = LevelManager.load_replay("_gut_replay_level")
	assert_eq(loaded.size(), 1)
	assert_eq(str(loaded[0]["type"]), "nuke")
	assert_eq(LevelManager.load_replay("_gut_no_such"), [], "missing replay is empty")


func test_winning_testplay_marks_the_level_verified() -> void:
	var game := _game()
	await wait_physics_frames(2)
	LevelManager.editing_path = TEST_LEVEL
	GameManager.current_level_id = "_gut_replay_level"
	game._on_level_completed(3, 1)
	var d: Dictionary = LevelManager.load_level_json(TEST_LEVEL)
	assert_true(bool(d.get("verified", false)), "verified stamped on win")
	var listed: Array = LevelManager.list_custom_levels().filter(
		func(i): return i["id"] == "_gut_replay_level")
	assert_eq(listed.size(), 1)
	assert_true(bool(listed[0]["verified"]), "browser sees the badge")
