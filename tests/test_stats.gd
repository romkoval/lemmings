extends "res://addons/gut/test.gd"

# US-3.4: lifetime statistics. Death causes flow from Lemming.die(cause)
# through GameManager into SaveManager totals, persisted with the save.


func before_each() -> void:
	SaveManager.stats = {"saved": 0, "dead": 0, "by_cause": {}, "levels_played": 0, "levels_won": 0}


func after_all() -> void:
	SaveManager.reset_progress()


func test_death_causes_are_counted_per_level_run() -> void:
	GameManager.start_level("t", 5)
	GameManager.notify_lemming_died("splat")
	GameManager.notify_lemming_died("splat")
	GameManager.notify_lemming_died("drowned")
	assert_eq(int(GameManager.death_causes["splat"]), 2)
	assert_eq(int(GameManager.death_causes["drowned"]), 1)
	GameManager.reset()


func test_completing_a_level_folds_stats() -> void:
	GameManager.start_level("t", 3)
	for i in range(3):
		GameManager.notify_lemming_spawned()
	GameManager.notify_lemming_saved()
	GameManager.notify_lemming_saved()
	GameManager.notify_lemming_died("burned")
	GameManager.complete_level(2)
	assert_eq(int(SaveManager.stats["saved"]), 2)
	assert_eq(int(SaveManager.stats["dead"]), 1)
	assert_eq(int(SaveManager.stats["by_cause"]["burned"]), 1)
	assert_eq(int(SaveManager.stats["levels_won"]), 1)
	assert_eq(int(SaveManager.stats["levels_played"]), 1)
	GameManager.reset()


func test_stats_survive_save_load() -> void:
	SaveManager.accumulate_stats(7, {"trapped": 2}, false)
	SaveManager.save_progress()
	SaveManager.stats = {"saved": 0, "dead": 0, "by_cause": {}, "levels_played": 0, "levels_won": 0}
	SaveManager.load_progress()
	assert_eq(int(SaveManager.stats["saved"]), 7)
	assert_eq(int(SaveManager.stats["by_cause"]["trapped"]), 2)
	assert_eq(int(SaveManager.stats["levels_won"]), 0, "lost runs don't count as wins")
