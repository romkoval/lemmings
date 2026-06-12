extends "res://addons/gut/test.gd"

# US-1.1: in-game release-rate control. The classic rules: the rate can be
# raised up to 99 and lowered back, but never below the level's starting rate;
# changes take effect on the entrance immediately.

const EntranceScene: PackedScene = preload("res://entities/entrance.tscn")
const HudScene: PackedScene = preload("res://ui/hud.tscn")


func _make_hud() -> HUD:
	var hud: HUD = HudScene.instantiate()
	add_child_autoqfree(hud)
	return hud


# ── Entrance: rate → spawn interval ─────────────────────────────────────────

func test_entrance_rate_change_shortens_interval() -> void:
	var entrance: Entrance = EntranceScene.instantiate()
	add_child_autoqfree(entrance)
	entrance.configure(10, 1)
	var slow: float = entrance.spawn_interval
	entrance.set_release_rate(99)
	assert_lt(entrance.spawn_interval, slow, "higher rate releases faster")
	assert_almost_eq(entrance.spawn_interval, 0.3, 0.001, "99 is the fastest interval")
	assert_almost_eq(slow, 3.0, 0.001, "1 is the slowest interval")


func test_entrance_rate_is_clamped_to_1_99() -> void:
	var entrance: Entrance = EntranceScene.instantiate()
	add_child_autoqfree(entrance)
	entrance.set_release_rate(500)
	assert_eq(entrance.release_rate, 99)
	entrance.set_release_rate(-3)
	assert_eq(entrance.release_rate, 1)


func test_entrance_keeps_elapsed_time_on_rate_change() -> void:
	# Raising the rate mid-wait must not reset the wait — the next lemming can
	# come out sooner, never later.
	var entrance: Entrance = EntranceScene.instantiate()
	add_child_autoqfree(entrance)
	entrance.configure(10, 50)
	entrance.time_since_spawn = 0.25
	entrance.set_release_rate(99)
	assert_almost_eq(entrance.time_since_spawn, 0.25, 0.001, "elapsed wait preserved")


# ── HUD: −/+ buttons, floor at the level's start rate, ceiling 99 ───────────

func test_hud_rate_starts_at_level_rate_and_respects_floor() -> void:
	var hud: HUD = _make_hud()
	watch_signals(hud)
	hud.configure(10, 5, 120, {}, 40)
	assert_eq(hud.release_rate, 40, "starts at the level's rate")
	assert_eq(hud.rate_label.text, "40")
	hud._change_rate(-1)
	assert_eq(hud.release_rate, 40, "cannot drop below the start rate")
	assert_signal_not_emitted(hud, "release_rate_changed")
	hud._change_rate(1)
	assert_eq(hud.release_rate, 41)
	assert_signal_emitted_with_parameters(hud, "release_rate_changed", [41])
	hud._update_labels()
	assert_eq(hud.rate_label.text, "41", "label follows the rate")


func test_hud_rate_is_capped_at_99() -> void:
	var hud: HUD = _make_hud()
	watch_signals(hud)
	hud.configure(10, 5, 120, {}, 98)
	hud._change_rate(1)
	hud._change_rate(1)
	assert_eq(hud.release_rate, 99, "capped at 99")
	assert_eq(get_signal_emit_count(hud, "release_rate_changed"), 1, "no emit once pinned at the cap")


func test_hud_hold_repeats_steps() -> void:
	# Holding the + button keeps stepping: one step on press, then a stream
	# after the initial delay (driven from _process).
	var hud: HUD = _make_hud()
	hud.configure(10, 5, 120, {}, 10)
	hud._on_rate_button_down(1)
	assert_eq(hud.release_rate, 11, "immediate step on press")
	hud._process(hud.RATE_REPEAT_DELAY + hud.RATE_REPEAT_INTERVAL * 5.5)
	assert_eq(hud.release_rate, 16, "held button streams repeats")
	hud._rate_hold_dir = 0
	var settled: int = hud.release_rate
	hud._process(1.0)
	assert_eq(hud.release_rate, settled, "release stops the stream")


func test_hud_configure_resets_rate_between_levels() -> void:
	var hud: HUD = _make_hud()
	hud.configure(10, 5, 120, {}, 30)
	hud._change_rate(20)
	assert_eq(hud.release_rate, 50)
	hud.configure(10, 5, 120, {}, 60)
	assert_eq(hud.release_rate, 60, "next level starts fresh at its own rate")
	assert_eq(hud.min_release_rate, 60)


# ── Wiring: HUD → Game → Entrance ───────────────────────────────────────────

func test_rate_change_reaches_the_entrance_through_the_game() -> void:
	var game: Game = (load("res://scenes/game/game.tscn") as PackedScene).instantiate() as Game
	add_child_autoqfree(game)
	await wait_physics_frames(2)
	var entrance: Entrance = game.current_level.entrance
	var start_rate: int = entrance.release_rate
	assert_eq(game.hud.release_rate, start_rate, "HUD starts at the level's rate")
	var interval_before: float = entrance.spawn_interval
	game.hud._change_rate(5)
	assert_eq(entrance.release_rate, start_rate + 5, "entrance follows the HUD")
	assert_lt(entrance.spawn_interval, interval_before, "spawn interval shortened")
	GameManager.reset()
