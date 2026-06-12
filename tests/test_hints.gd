extends "res://addons/gut/test.gd"

# US-5.2: onboarding hints — a one-time dismissible tip per level, with a
# global off-switch in the settings.

const TEST_LEVEL: String = "user://custom_levels/_gut_hint_level.json"

const SAMPLE: Dictionary = {
	"id": "_gut_hint_level", "name": "hint gut", "custom": true,
	"total_lemmings": 2, "save_required": 1, "time_limit": 120, "release_rate": 50,
	"skill_counts": {"climber": 0, "floater": 0, "bomber": 0, "blocker": 0,
		"builder": 0, "basher": 0, "miner": 0, "digger": 1},
	"entrance_pos": [80, 398], "entrance_direction": 1, "exit_pos": [620, 446],
	"terrain_rects": [{"x": 0, "y": 29, "w": 45, "h": 4}],
	"hint": "Тестовая подсказка",
}


func before_each() -> void:
	SaveManager.settings["hints_enabled"] = true
	SaveManager.settings["hints_shown"] = {}


func after_each() -> void:
	LevelManager.delete_custom_level(TEST_LEVEL)
	SaveManager.settings.erase("hints_shown")
	SaveManager.settings["hints_enabled"] = true
	GameManager.reset()


func _game() -> Game:
	LevelManager.save_level_json(TEST_LEVEL, SAMPLE)
	var game: Game = (load("res://scenes/game/game.tscn") as PackedScene).instantiate() as Game
	game.initial_level_path = TEST_LEVEL
	add_child_autoqfree(game)
	return game


func test_hint_shows_once_and_remembers_dismissal() -> void:
	var game := _game()
	await wait_physics_frames(2)
	assert_not_null(game._hint_panel, "hint shown on first visit")
	game._dismiss_hint()
	assert_null(game._hint_panel, "dismissed")
	assert_true(bool((SaveManager.settings["hints_shown"] as Dictionary).get("_gut_hint_level", false)),
		"dismissal persisted")
	# Reload the same level: no hint the second time.
	game.load_level(TEST_LEVEL)
	await wait_physics_frames(2)
	assert_null(game._hint_panel, "shown only once per level")


func test_hints_can_be_disabled_globally() -> void:
	SaveManager.settings["hints_enabled"] = false
	var game := _game()
	await wait_physics_frames(2)
	assert_null(game._hint_panel, "global off-switch respected")


func test_levels_without_hint_show_nothing() -> void:
	var bare: Dictionary = SAMPLE.duplicate(true)
	bare.erase("hint")
	LevelManager.save_level_json(TEST_LEVEL, bare)
	var game: Game = (load("res://scenes/game/game.tscn") as PackedScene).instantiate() as Game
	game.initial_level_path = TEST_LEVEL
	add_child_autoqfree(game)
	await wait_physics_frames(2)
	assert_null(game._hint_panel)
