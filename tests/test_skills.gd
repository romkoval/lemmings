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


# ── Regressions: mid-skill assignment, nuke craters, fast-forward ────────────

func test_flag_skill_does_not_freeze_a_builder() -> void:
	# Giving a BUILDING lemming a climber must not clobber its BuilderSkill:
	# that left it frozen mid-staircase (BUILDING with no tick driver), turning
	# the whole crowd away. The flag applies; the builder keeps building.
	var level: Level = (load("res://scenes/game/level.tscn") as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	var lem: Lemming = LemmingScene.instantiate()
	level.add_child(lem)
	autoqfree(lem)
	await wait_physics_frames(1)
	lem.global_position = Vector2(80, 448)
	level.fill_rect_px(Rect2i(48, 464, 96, 16))   # floor under and ahead
	var builder: BuilderSkill = BuilderSkill.new()
	assert_true(lem.assign_skill(builder))
	assert_eq(lem.current_state, Lemming.State.BUILDING)
	assert_true(lem.assign_skill(ClimberSkill.new()), "climber accepted mid-build")
	assert_true(lem.is_climber, "flag set")
	assert_eq(lem.active_skill_node, builder, "builder still drives the lemming")
	var planks_before: int = builder.planks_laid
	for i in range(3):
		lem._process_skill(1.0 / 60.0)
	assert_gt(builder.planks_laid, planks_before, "still laying planks — not frozen")
	assert_eq(lem.current_state, Lemming.State.BUILDING)


func test_nuked_lemming_blasts_a_crater() -> void:
	# Nuke calls start_bomb_countdown() directly (no skill node) — the blast
	# must still carve terrain, identically to a hand-assigned bomber.
	var level: Level = (load("res://scenes/game/level.tscn") as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	var lem: Lemming = LemmingScene.instantiate()
	level.add_child(lem)
	autoqfree(lem)
	await wait_physics_frames(1)
	lem.global_position = Vector2(80, 448)   # feet (88, 464)
	level.fill_rect_px(Rect2i(64, 464, 48, 32))
	assert_true(level.is_solid_px(Vector2(88.5, 470.5)), "ground before blast")
	GameManager.set_state(GameManager.GameState.PLAYING)
	lem.start_bomb_countdown()
	lem.bomb_timer = 0.02                     # fast-forward the fuse
	# US-1.6: the fuse end starts an "Oh no!" shrug — no crater yet…
	await wait_physics_frames(4)
	assert_true(level.is_solid_px(Vector2(88.5, 470.5)), "ground intact during the shrug")
	assert_eq(lem.current_state, Lemming.State.EXPLODING, "still shrugging")
	# …the blast lands only after OH_NO_SECONDS.
	await wait_physics_frames(int(Lemming.OH_NO_SECONDS * 60.0) + 6)
	assert_false(level.is_solid_px(Vector2(88.5, 470.5)), "crater carved after the shrug")
	GameManager.set_state(GameManager.GameState.MENU)


func test_fast_forward_raises_physics_tick_rate() -> void:
	# Engine.time_scale alone doesn't add physics ticks in Godot 4, and the
	# lemmings move whole pixels per tick — fast-forward must raise the tick
	# rate too, and restore it cleanly.
	var hud = (load("res://ui/hud.tscn") as PackedScene).instantiate()
	add_child_autoqfree(hud)
	await wait_physics_frames(1)
	hud._on_fast_toggled(true)
	assert_eq(Engine.time_scale, 3.0, "clock sped up")
	assert_eq(Engine.physics_ticks_per_second, 180, "simulation sped up")
	hud._on_fast_toggled(false)
	assert_eq(Engine.time_scale, 1.0)
	assert_eq(Engine.physics_ticks_per_second, 60)
