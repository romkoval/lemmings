extends "res://addons/gut/test.gd"

# A floater opens its parachute and descends slowly whenever it falls — whether
# the umbrella was given mid-air or earlier while the lemming was still walking.
# See Lemming._process_falling / FloaterSkill.

const LemmingScene: PackedScene = preload("res://entities/lemming.tscn")

var _lem: Lemming


func before_each() -> void:
	_lem = LemmingScene.instantiate()
	add_child_autoqfree(_lem)
	GameManager.set_state(GameManager.GameState.PLAYING)


func after_each() -> void:
	GameManager.set_state(GameManager.GameState.MENU)


func test_floater_skill_sets_flag_while_walking() -> void:
	var skill: FloaterSkill = FloaterSkill.new()
	assert_true(skill.can_apply(_lem))
	skill.apply(_lem)
	assert_true(_lem.is_floater)


func test_floater_given_early_opens_parachute_on_fall() -> void:
	# Umbrella given while walking, then the lemming starts to fall: it must enter
	# FLOATING (parachute), not keep dropping in FALLING.
	FloaterSkill.new().apply(_lem)        # sets is_floater while WALKING
	_lem.change_state(Lemming.State.FALLING)
	await wait_physics_frames(2)
	assert_eq(_lem.current_state, Lemming.State.FLOATING)


func test_floater_given_mid_fall_opens_parachute() -> void:
	_lem.change_state(Lemming.State.FALLING)
	FloaterSkill.new().apply(_lem)
	assert_eq(_lem.current_state, Lemming.State.FLOATING)


func test_floater_descends_slowly() -> void:
	_lem.is_floater = true
	_lem.global_position = Vector2(100, 100)
	_lem.change_state(Lemming.State.FLOATING)
	var y0: float = _lem.global_position.y
	await wait_physics_frames(10)
	var dy: float = _lem.global_position.y - y0
	assert_gt(dy, 0.0, "floater still descends")
	assert_lt(dy, 30.0, "floater descends slowly (gentle gravity)")