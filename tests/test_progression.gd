extends "res://addons/gut/test.gd"

# US-2.3: progression and personal bests. SaveManager keeps the best result
# per level (more saved wins; ties broken by time left), levels unlock in
# order within a rank, and everything survives the save/load round-trip.


func before_each() -> void:
	SaveManager.completed_levels.clear()
	SaveManager.level_results.clear()


func after_all() -> void:
	SaveManager.completed_levels.clear()
	SaveManager.level_results.clear()
	SaveManager.save_progress()


func test_record_keeps_only_the_best() -> void:
	assert_true(SaveManager.record_result("fun_01", 7, 10, 60), "first attempt is a best")
	assert_false(SaveManager.record_result("fun_01", 5, 10, 200), "fewer saved never beats more")
	assert_eq(int(SaveManager.best_result("fun_01")["saved"]), 7)
	assert_true(SaveManager.record_result("fun_01", 7, 10, 90), "tie broken by time left")
	assert_eq(int(SaveManager.best_result("fun_01")["time_left"]), 90)
	assert_true(SaveManager.record_result("fun_01", 9, 10, 10), "more saved always wins")
	assert_eq(int(SaveManager.best_result("fun_01")["saved"]), 9)


func test_levels_unlock_in_order() -> void:
	assert_true(SaveManager.is_level_unlocked("tricky", 1), "first level of a rank is open")
	assert_false(SaveManager.is_level_unlocked("tricky", 2), "next is locked until previous done")
	SaveManager.mark_level_complete("tricky_01")
	assert_true(SaveManager.is_level_unlocked("tricky", 2), "completing unlocks the next")
	assert_false(SaveManager.is_level_unlocked("tricky", 3), "but only the next")


func test_results_survive_save_load_round_trip() -> void:
	SaveManager.record_result("tricky_03", 4, 10, 33)
	SaveManager.mark_level_complete("tricky_03")
	SaveManager.save_progress()
	SaveManager.completed_levels.clear()
	SaveManager.level_results.clear()
	SaveManager.load_progress()
	assert_true(SaveManager.is_level_complete("tricky_03"), "completion persisted")
	var best: Dictionary = SaveManager.best_result("tricky_03")
	assert_eq(int(best.get("saved", -1)), 4, "best result persisted")
	assert_eq(int(best.get("time_left", -1)), 33)


func test_reset_clears_records_too() -> void:
	SaveManager.record_result("fun_02", 10, 10, 100)
	SaveManager.reset_progress()
	assert_true(SaveManager.best_result("fun_02").is_empty(), "reset wipes records")
