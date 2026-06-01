class_name BlockerSkill
extends BaseSkill

const SKILL_NAME: String = "blocker"


func get_skill_name() -> String:
	return SKILL_NAME


func can_apply(lemming: Lemming) -> bool:
	return lemming.current_state == Lemming.State.WALKING


func apply(lemming: Lemming) -> void:
	lemming.change_state(Lemming.State.BLOCKING)
