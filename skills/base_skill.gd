class_name BaseSkill
extends RefCounted

const SKILL_NAME: String = "base"


func get_skill_name() -> String:
	return SKILL_NAME


func can_apply(_lemming: Lemming) -> bool:
	return true


# Driver skills (builder/digger/basher/miner) are ticked from the lemming's
# skill state every physics frame and own Lemming.active_skill_node. Flag and
# one-shot skills (climber, floater, blocker, bomber) keep the default false so
# they never clobber a driver mid-work.
func needs_tick() -> bool:
	return false


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
