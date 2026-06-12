extends "res://addons/gut/test.gd"

# US-1.2: crowd-aware lemming selection (SkillManager.pick_target).
# Touch taps are imprecise; in a crowd the tap must go to the lemming the
# player almost certainly means: one the selected skill can apply to, free
# walkers before busy workers, and the one heading toward the tap point.

const LemmingScene: PackedScene = preload("res://entities/lemming.tscn")

var _sm: SkillManager


func before_each() -> void:
	_sm = SkillManager.new()
	add_child_autoqfree(_sm)


func _lem(pos: Vector2, dir: int = 1, state: Lemming.State = Lemming.State.WALKING) -> Lemming:
	var lem: Lemming = LemmingScene.instantiate()
	add_child_autoqfree(lem)
	lem.global_position = pos
	lem.direction = dir
	if state != Lemming.State.WALKING:
		lem.change_state(state)
	return lem


func test_ambiguous_tap_prefers_walker_direct_tap_respects_worker() -> void:
	# Both eligible (bomber applies to anyone). An ambiguous tap between them
	# goes to the free walker; a point-blank tap on the builder means the
	# builder — explicit aim is respected.
	_sm.selected_skill = "bomber"
	var builder := _lem(Vector2(100, 100), 1, Lemming.State.BUILDING)
	var walker := _lem(Vector2(121, 100))
	assert_eq(_sm.pick_target([builder, walker], Vector2(110, 100), 24.0), walker,
		"ambiguous crowd tap prefers the free walker")
	assert_eq(_sm.pick_target([builder, walker], Vector2(100, 100), 24.0), builder,
		"direct hit picks the worker under the finger")


func test_eligible_beats_closer_ineligible() -> void:
	# Climber selected: the lemming that is already a climber is skipped in
	# favour of one that can actually receive the skill.
	_sm.selected_skill = "climber"
	var already := _lem(Vector2(100, 100))
	already.is_climber = true
	var fresh := _lem(Vector2(118, 100))
	var picked: Lemming = _sm.pick_target([already, fresh], Vector2(100, 100), 24.0)
	assert_eq(picked, fresh, "skill goes to a lemming it can apply to")


func test_blocker_is_skipped_unless_bombing() -> void:
	# A blocker is ineligible for digger (needs WALKING) — the walker behind it
	# gets the pick. With bomber selected the same tap hits the blocker.
	var blocker := _lem(Vector2(100, 100), 1, Lemming.State.BLOCKING)
	var walker := _lem(Vector2(116, 100))
	_sm.selected_skill = "digger"
	assert_eq(_sm.pick_target([blocker, walker], Vector2(100, 100), 24.0), walker,
		"digger tap skips the blocker")
	_sm.selected_skill = "bomber"
	assert_eq(_sm.pick_target([blocker, walker], Vector2(100, 100), 24.0), blocker,
		"bomber tap can still hit the blocker")


func test_prefers_lemming_heading_toward_tap() -> void:
	# Two walkers around the tap: the slightly-farther one walking toward the
	# tap point beats the closer one walking away.
	_sm.selected_skill = "bomber"
	var away := _lem(Vector2(90, 100), -1)     # left of tap, walking left (away)
	var toward := _lem(Vector2(112, 100), -1)  # right of tap, walking left (toward)
	var picked: Lemming = _sm.pick_target([away, toward], Vector2(100, 100), 24.0)
	assert_eq(picked, toward, "direction toward the tap wins over raw distance")


func test_distance_breaks_full_ties() -> void:
	_sm.selected_skill = "bomber"
	var near := _lem(Vector2(104, 100), 1)
	var far := _lem(Vector2(110, 100), 1)
	var picked: Lemming = _sm.pick_target([far, near], Vector2(100, 100), 24.0)
	assert_eq(picked, near, "nearest wins when everything else is equal")


func test_out_of_reach_and_terminal_are_ignored() -> void:
	_sm.selected_skill = "bomber"
	var distant := _lem(Vector2(200, 100))
	assert_null(_sm.pick_target([distant], Vector2(100, 100), 24.0), "nothing within reach")
	var exited := _lem(Vector2(102, 100))
	exited.change_state(Lemming.State.EXITED)
	assert_null(_sm.pick_target([exited], Vector2(100, 100), 24.0), "terminal states unselectable")


func test_no_selected_skill_falls_back_to_walker_priority() -> void:
	# Highlighting can run before a skill is chosen — ranking still applies.
	var worker := _lem(Vector2(100, 100), 1, Lemming.State.DIGGING)
	var walker := _lem(Vector2(121, 100))
	var picked: Lemming = _sm.pick_target([worker, walker], Vector2(110, 100), 24.0)
	assert_eq(picked, walker)
