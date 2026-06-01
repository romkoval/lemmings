extends "res://addons/gut/test.gd"

const LemmingScene: PackedScene = preload("res://entities/lemming.tscn")

var _lemming: Lemming


func before_each() -> void:
	_lemming = LemmingScene.instantiate()
	add_child_autoqfree(_lemming)


func test_climber_sets_flag() -> void:
	var skill: ClimberSkill = ClimberSkill.new()
	assert_true(skill.can_apply(_lemming))
	skill.apply(_lemming)
	assert_true(_lemming.is_climber)


func test_climber_cannot_be_applied_twice() -> void:
	_lemming.is_climber = true
	var skill: ClimberSkill = ClimberSkill.new()
	assert_false(skill.can_apply(_lemming))


func test_floater_sets_flag() -> void:
	var skill: FloaterSkill = FloaterSkill.new()
	skill.apply(_lemming)
	assert_true(_lemming.is_floater)


func test_blocker_only_from_walking() -> void:
	var skill: BlockerSkill = BlockerSkill.new()
	assert_true(skill.can_apply(_lemming))
	_lemming.change_state(Lemming.State.FALLING)
	assert_false(skill.can_apply(_lemming))


func test_bomber_starts_countdown() -> void:
	var skill: BomberSkill = BomberSkill.new()
	skill.apply(_lemming)
	assert_eq(_lemming.current_state, Lemming.State.EXPLODING)
	assert_almost_eq(_lemming.bomb_timer, Lemming.BOMB_FUSE_SECONDS, 0.01)


func test_digger_only_from_walking() -> void:
	var skill: DiggerSkill = DiggerSkill.new()
	assert_true(skill.can_apply(_lemming))
	skill.apply(_lemming)
	assert_eq(_lemming.current_state, Lemming.State.DIGGING)


func test_builder_state_change() -> void:
	var skill: BuilderSkill = BuilderSkill.new()
	skill.apply(_lemming)
	assert_eq(_lemming.current_state, Lemming.State.BUILDING)


func test_all_skills_have_distinct_names() -> void:
	var names: Array = []
	for sname in SkillManager.SKILL_SCRIPTS.keys():
		var script: Script = SkillManager.SKILL_SCRIPTS[sname]
		var instance: BaseSkill = script.new()
		var n: String = instance.get_skill_name()
		assert_does_not_have(names, n)
		names.append(n)
	assert_eq(names.size(), 8)
