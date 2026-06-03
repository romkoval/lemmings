extends "res://addons/gut/test.gd"

const LemmingScene: PackedScene = preload("res://entities/lemming.tscn")

var _lemming: Lemming


func before_each() -> void:
	_lemming = LemmingScene.instantiate()
	add_child_autoqfree(_lemming)


func test_initial_state_is_walking() -> void:
	assert_eq(_lemming.current_state, Lemming.State.WALKING)


func test_initial_flags() -> void:
	assert_false(_lemming.is_climber)
	assert_false(_lemming.is_floater)


func test_change_state_emits_signal() -> void:
	watch_signals(_lemming)
	_lemming.change_state(Lemming.State.FALLING)
	assert_signal_emitted(_lemming, "state_changed")
	assert_eq(_lemming.current_state, Lemming.State.FALLING)


func test_change_state_to_same_does_nothing() -> void:
	watch_signals(_lemming)
	_lemming.change_state(Lemming.State.WALKING)
	assert_signal_not_emitted(_lemming, "state_changed")


func test_turn_around_flips_direction() -> void:
	_lemming.direction = 1
	_lemming.turn_around()
	assert_eq(_lemming.direction, -1)
	_lemming.turn_around()
	assert_eq(_lemming.direction, 1)


func test_falling_resets_fall_distance() -> void:
	_lemming.global_position = Vector2(0, 100)
	_lemming.change_state(Lemming.State.FALLING)
	assert_eq(_lemming.fall_start_y, 100.0)
	assert_eq(_lemming.fall_distance, 0.0)


func test_falls_off_bottom_of_world_dies() -> void:
	# A lemming below the kill plane must die so the level can resolve,
	# instead of falling forever (ТЗ §1.3).
	GameManager.start_level("test", 1)
	watch_signals(_lemming)
	_lemming.global_position = Vector2(100, Lemming.KILL_PLANE_Y + 50)
	_lemming.change_state(Lemming.State.FALLING)
	_lemming._physics_process(0.016)
	assert_signal_emitted(_lemming, "lemming_died")
	GameManager.reset()
