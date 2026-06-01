class_name SkillManager
extends Node

signal skill_selected(skill_name: String)
signal skill_assigned(skill_name: String, lemming: Lemming)
signal skill_count_changed(skill_name: String, new_count: int)

const SKILL_SCRIPTS: Dictionary = {
	"climber": preload("res://skills/climber.gd"),
	"floater": preload("res://skills/floater.gd"),
	"bomber": preload("res://skills/bomber.gd"),
	"blocker": preload("res://skills/blocker.gd"),
	"builder": preload("res://skills/builder.gd"),
	"basher": preload("res://skills/basher.gd"),
	"miner": preload("res://skills/miner.gd"),
	"digger": preload("res://skills/digger.gd"),
}

var skill_counts: Dictionary = {}
var selected_skill: String = ""


func configure(counts: Dictionary) -> void:
	skill_counts = counts.duplicate(true)
	for skill_name in SKILL_SCRIPTS.keys():
		if not skill_counts.has(skill_name):
			skill_counts[skill_name] = 0
	selected_skill = ""


func select_skill(skill_name: String) -> bool:
	if not SKILL_SCRIPTS.has(skill_name):
		return false
	if get_count(skill_name) <= 0:
		return false
	selected_skill = skill_name
	skill_selected.emit(skill_name)
	return true


func get_count(skill_name: String) -> int:
	return int(skill_counts.get(skill_name, 0))


func assign_to(lemming: Lemming) -> bool:
	if lemming == null or selected_skill == "":
		return false
	if get_count(selected_skill) <= 0:
		return false
	var skill_script: Script = SKILL_SCRIPTS[selected_skill]
	var skill: BaseSkill = skill_script.new()
	if not lemming.assign_skill(skill):
		return false
	skill_counts[selected_skill] -= 1
	skill_assigned.emit(selected_skill, lemming)
	skill_count_changed.emit(selected_skill, skill_counts[selected_skill])
	AudioManager.play_sfx("skill_assign")
	return true
