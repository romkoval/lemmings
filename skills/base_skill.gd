class_name BaseSkill
extends RefCounted

const SKILL_NAME: String = "base"


func get_skill_name() -> String:
	return SKILL_NAME


func can_apply(_lemming: Lemming) -> bool:
	return true


func apply(_lemming: Lemming) -> void:
	pass


func tick(_lemming: Lemming) -> void:
	pass


func _get_level(lemming: Lemming) -> Level:
	var node: Node = lemming.get_parent()
	while node:
		if node is Level:
			return node
		node = node.get_parent()
	return null
