extends "res://addons/gut/test.gd"

# A blocker stops walkers sharing its ground but must NOT block lemmings on a
# different level (a row or more above/below it) — proximity is checked in both
# X and Y. See Lemming._is_blocker_at_front.

const LemmingScene: PackedScene = preload("res://entities/lemming.tscn")

var _blocker: Lemming
var _walker: Lemming


func before_each() -> void:
	_blocker = LemmingScene.instantiate()
	_walker = LemmingScene.instantiate()
	add_child_autoqfree(_blocker)
	add_child_autoqfree(_walker)
	_blocker.change_state(Lemming.State.BLOCKING)
	_walker.direction = 1


func test_blocks_walker_on_same_level() -> void:
	_walker.global_position = Vector2(112, 400)
	_blocker.global_position = Vector2(120, 400)  # 8px ahead, same row
	assert_true(_walker._is_blocker_at_front())


func test_does_not_block_when_blocker_is_a_row_above() -> void:
	_walker.global_position = Vector2(112, 400)
	_blocker.global_position = Vector2(120, 384)  # one tile (16px) up
	assert_false(_walker._is_blocker_at_front())


func test_does_not_block_when_blocker_is_a_row_below() -> void:
	_walker.global_position = Vector2(112, 400)
	_blocker.global_position = Vector2(120, 416)  # one tile (16px) down
	assert_false(_walker._is_blocker_at_front())


func test_does_not_block_when_behind() -> void:
	_walker.global_position = Vector2(120, 400)
	_blocker.global_position = Vector2(112, 400)  # behind a right-facing walker
	assert_false(_walker._is_blocker_at_front())
