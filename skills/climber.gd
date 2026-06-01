class_name ClimberSkill
extends BaseSkill


func get_skill_name() -> String:
	return "climber"


func can_apply(lemming: Lemming) -> bool:
	return not lemming.is_climber


func apply(lemming: Lemming) -> void:
	lemming.is_climber = true
