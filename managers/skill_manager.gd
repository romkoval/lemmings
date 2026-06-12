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


# A tap closer than this is a deliberate hit on THAT lemming (half its body
# width) — it outranks the crowd heuristics below.
const DIRECT_HIT_RADIUS: float = 8.0

# US-1.2: pick the lemming a tap should target. Touch is imprecise and crowds
# are dense — plain nearest-distance grabs whoever happens to be closest, which
# in a working crowd is usually the one already busy. Rank candidates instead:
#   1. eligible for the selected skill (can_apply) before ineligible;
#   2. a direct hit (finger right on a lemming) before the crowd around it —
#      so a blocker can still be bombed point-blank;
#   3. free walkers before busy ones (WALKING beats BUILDING/DIGGING/…);
#   4. walking toward the tap point before walking away;
#   5. nearest.
# A blocker, for example, is ineligible for everything but bomber — tapping a
# crowd around it never wastes a skill on the blocker, yet a point-blank tap
# with the bomber selected detonates exactly it.
func pick_target(lemmings: Array, world_pos: Vector2, max_dist: float) -> Lemming:
	var skill: BaseSkill = null
	if SKILL_SCRIPTS.has(selected_skill):
		skill = (SKILL_SCRIPTS[selected_skill] as Script).new()
	var best: Lemming = null
	var best_key: Array = []
	for n in lemmings:
		var lem := n as Lemming
		if lem == null or lem.current_state in Lemming.TERMINAL_STATES:
			continue
		var dist: float = lem.global_position.distance_to(world_pos)
		if dist > max_dist:
			continue
		var ineligible: int = 0 if (skill == null or skill.can_apply(lem)) else 1
		var not_direct: int = 0 if dist <= DIRECT_HIT_RADIUS else 1
		var busy: int = 0 if lem.current_state == Lemming.State.WALKING else 1
		var dx: float = world_pos.x - lem.global_position.x
		var facing_away: int = 0 if (absf(dx) < 1.0 or int(signf(dx)) == lem.direction) else 1
		# Arrays compare lexicographically — earlier criteria dominate later ones.
		var key: Array = [ineligible, not_direct, busy, facing_away, dist]
		if best == null or key < best_key:
			best = lem
			best_key = key
	return best


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
