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


# ── Walkers turn around at a builder met head-on ───────────────────────────

func test_walker_turns_at_head_on_builder() -> void:
	# Builder right in front, facing back toward the walker → turn.
	_blocker.change_state(Lemming.State.BUILDING)
	_blocker.direction = -1
	_blocker.global_position = Vector2(120, 400)
	_walker.direction = 1
	_walker.global_position = Vector2(112, 400)
	assert_true(_walker._is_head_on_builder_at_front())


func test_follower_not_turned_by_builder() -> void:
	# Builder in front but facing the SAME way (a follower coming up behind it)
	# → not turned, so it can climb the staircase.
	_blocker.change_state(Lemming.State.BUILDING)
	_blocker.direction = 1
	_blocker.global_position = Vector2(120, 400)
	_walker.direction = 1
	_walker.global_position = Vector2(112, 400)
	assert_false(_walker._is_head_on_builder_at_front())


func test_builder_on_other_level_does_not_turn() -> void:
	# Builder a row up shouldn't turn a walker passing below it.
	_blocker.change_state(Lemming.State.BUILDING)
	_blocker.direction = -1
	_blocker.global_position = Vector2(120, 384)
	_walker.direction = 1
	_walker.global_position = Vector2(112, 400)
	assert_false(_walker._is_head_on_builder_at_front())
