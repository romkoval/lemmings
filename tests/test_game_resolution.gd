extends "res://addons/gut/test.gd"

# Regression tests for the level win/lose resolution flow.
# These guard the P0 bug where lemming saved/died events never triggered
# `all_lemmings_resolved`, so a level could neither be won nor lost.

func after_each() -> void:
	GameManager.reset()


func test_resolves_only_after_all_spawned_lemmings_terminal() -> void:
	watch_signals(GameManager)
	GameManager.start_level("test", 3)
	GameManager.notify_lemming_spawned()
	GameManager.notify_lemming_spawned()
	GameManager.notify_lemming_spawned()
	GameManager.notify_lemming_saved()
	GameManager.notify_lemming_died()
	# Two of three resolved — not done yet.
	assert_signal_not_emitted(GameManager, "all_lemmings_resolved")
	GameManager.notify_lemming_saved()
	assert_signal_emitted(GameManager, "all_lemmings_resolved")


func test_does_not_resolve_before_full_spawn() -> void:
	watch_signals(GameManager)
	GameManager.start_level("test", 3)
	# Only one has spawned and it saved — the rest are still in the hatch.
	GameManager.notify_lemming_spawned()
	GameManager.notify_lemming_saved()
	assert_signal_not_emitted(GameManager, "all_lemmings_resolved")


func test_complete_level_wins_when_quota_met() -> void:
	watch_signals(GameManager)
	GameManager.start_level("test", 2)
	GameManager.notify_lemming_spawned()
	GameManager.notify_lemming_spawned()
	GameManager.notify_lemming_saved()
	GameManager.notify_lemming_saved()
	GameManager.complete_level(2)
	assert_signal_emitted(GameManager, "level_completed")
	assert_signal_not_emitted(GameManager, "level_failed")
	assert_eq(GameManager.current_state, GameManager.GameState.RESULT)


func test_complete_level_fails_when_quota_missed() -> void:
	watch_signals(GameManager)
	GameManager.start_level("test", 2)
	GameManager.notify_lemming_spawned()
	GameManager.notify_lemming_spawned()
	GameManager.notify_lemming_saved()
	GameManager.notify_lemming_died()
	GameManager.complete_level(2)
	assert_signal_emitted(GameManager, "level_failed")
	assert_signal_not_emitted(GameManager, "level_completed")


func test_complete_level_is_idempotent() -> void:
	watch_signals(GameManager)
	GameManager.start_level("test", 1)
	GameManager.notify_lemming_spawned()
	GameManager.notify_lemming_saved()
	GameManager.complete_level(1)
	# A second call (e.g. timer expiry after resolution) must not re-fire.
	GameManager.complete_level(1)
	assert_signal_emitted_with_parameters(GameManager, "level_completed", [1, 1])
	assert_eq(get_signal_emit_count(GameManager, "level_completed"), 1)
