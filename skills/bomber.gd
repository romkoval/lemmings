class_name BomberSkill
extends BaseSkill

# Lights the fuse; the explosion itself (crater carving, death) lives in
# Lemming._process_exploding so nuked lemmings blast terrain identically.


func get_skill_name() -> String:
	return "bomber"


func can_apply(lemming: Lemming) -> bool:
	return lemming.current_state != Lemming.State.EXPLODING


func apply(lemming: Lemming) -> void:
	lemming.start_bomb_countdown()
