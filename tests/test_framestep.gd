extends "res://addons/gut/test.gd"

# US-3.3: framestep — while paused, one button press advances the simulation
# by exactly one physics tick, then pauses again. Powered by the sim_tick
# clock, so the step is tick-exact, not time-approximate.


func after_each() -> void:
	GameManager.reset()


func test_framestep_advances_exactly_one_tick() -> void:
	GameManager.start_level("t", 1)
	await wait_physics_frames(2)
	GameManager.set_state(GameManager.GameState.PAUSED)
	await wait_physics_frames(2)
	var t0: int = GameManager.sim_tick
	GameManager.framestep()
	await wait_physics_frames(6)
	assert_eq(GameManager.sim_tick, t0 + 1, "exactly one tick ran")
	assert_eq(GameManager.current_state, GameManager.GameState.PAUSED, "paused again")
	# And it composes: each press is one more tick.
	GameManager.framestep()
	await wait_physics_frames(6)
	assert_eq(GameManager.sim_tick, t0 + 2)


func test_framestep_is_noop_outside_pause() -> void:
	GameManager.start_level("t", 1)
	await wait_physics_frames(1)
	var before: int = GameManager.sim_tick
	GameManager.framestep()   # PLAYING — must not double-step or pause
	await wait_physics_frames(3)
	assert_eq(GameManager.current_state, GameManager.GameState.PLAYING, "still playing")
	assert_gt(GameManager.sim_tick, before, "clock unaffected, keeps running")
