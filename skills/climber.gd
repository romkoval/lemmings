class_name ClimberSkill
extends BaseSkill

const SKILL_NAME: String = "climber"


func get_skill_name() -> String:
	return SKILL_NAME


func can_apply(lemming: Lemming) -> bool:
	return not lemming.is_climber


func apply(lemming: Lemming) -> void:
	lemming.is_climber = true
