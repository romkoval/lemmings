extends "res://addons/gut/test.gd"

var _sm: SkillManager


func before_each() -> void:
	_sm = SkillManager.new()
	add_child_autoqfree(_sm)


func test_configure_fills_missing_keys() -> void:
	_sm.configure({"digger": 5})
	assert_eq(_sm.get_count("digger"), 5)
	assert_eq(_sm.get_count("climber"), 0)


func test_select_unavailable_skill_returns_false() -> void:
	_sm.configure({"digger": 0})
	assert_false(_sm.select_skill("digger"))


func test_select_available_skill_returns_true() -> void:
	_sm.configure({"digger": 3})
	assert_true(_sm.select_skill("digger"))
	assert_eq(_sm.selected_skill, "digger")


func test_assign_without_selection_returns_false() -> void:
	_sm.configure({"climber": 1})
	var lem: Lemming = preload("res://entities/lemming.tscn").instantiate()
	add_child_autoqfree(lem)
	assert_false(_sm.assign_to(lem))


func test_assign_decrements_count() -> void:
	_sm.configure({"climber": 1})
	_sm.select_skill("climber")
	var lem: Lemming = preload("res://entities/lemming.tscn").instantiate()
	add_child_autoqfree(lem)
	assert_true(_sm.assign_to(lem))
	assert_eq(_sm.get_count("climber"), 0)
	assert_true(lem.is_climber)
