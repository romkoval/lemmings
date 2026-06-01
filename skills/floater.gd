class_name FloaterSkill
extends BaseSkill

const SKILL_NAME: String = "floater"


func get_skill_name() -> String:
	return SKILL_NAME


func can_apply(lemming: Lemming) -> bool:
	return not lemming.is_floater


func apply(lemming: Lemming) -> void:
	lemming.is_floater = true
	if lemming.current_state == Lemming.State.FALLING:
		lemming.change_state(Lemming.State.FLOATING)
