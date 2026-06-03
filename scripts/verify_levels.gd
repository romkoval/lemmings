extends SceneTree
# Headless solvability verifier. Boots the real Game scene for a Fun level,
# replays a scripted reference solution (skill assignments at given frames and
# world positions), and reports whether the save quota is met.
#
#   /tmp/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 2000 \
#       -s scripts/verify_levels.gd --level=fun/level_03
#   ...--level=all   runs every Fun level and prints a PASS/FAIL summary.
#
# A step is {"f": frame, "skill": name, "x": world_x, "y": world_y}: the named
# skill is selected and assigned to the lemming nearest (x, y) — a stand-in for
# a player tapping that lemming. Autoloads are reached via /root/... because the
# global identifiers aren't bound when a script replaces the main loop with -s.

const SOLUTIONS: Dictionary = {
	"fun/level_01": [],  # just walk — no skills needed
	"fun/level_06": [],  # sandbox: all skills unlocked, walkable to the exit
	"fun/level_02": [    # digger: one shaft, the rest follow down to the exit
		{"f": 275, "skill": "digger", "x": 352, "y": 399},
	],
	"fun/level_03": [    # builder: a stairway up to the exit, the crowd climbs it
		{"f": 260, "skill": "builder", "x": 340, "y": 400},
	],
	"fun/level_04": [    # climber: assign at the hatch, each scales the wall
		{"f": 30, "skill": "climber", "x": 90, "y": 460},
		{"f": 130, "skill": "climber", "x": 90, "y": 460},
		{"f": 230, "skill": "climber", "x": 90, "y": 460},
		{"f": 330, "skill": "climber", "x": 90, "y": 460},
		{"f": 430, "skill": "climber", "x": 90, "y": 460},
		{"f": 530, "skill": "climber", "x": 90, "y": 460},
		{"f": 630, "skill": "climber", "x": 90, "y": 460},
		{"f": 730, "skill": "climber", "x": 90, "y": 460},
	],
	"fun/level_05": [    # builder: bridge the chasm, the crowd crosses
		{"f": 170, "skill": "builder", "x": 250, "y": 400},
	],
}

const ST_RESULT: int = 3
const MAX_FRAMES: int = 6000

var _gm: Node = null


func _init() -> void:
	var level := "all"
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--level="):
			level = arg.substr("--level=".length())
	_run.call_deferred(level)


func _run(level: String) -> void:
	_gm = root.get_node_or_null("/root/GameManager")
	var levels: Array = SOLUTIONS.keys() if level == "all" else [level]
	var all_pass := true
	for lv in levels:
		var pass_one: bool = await _verify(lv)
		all_pass = all_pass and pass_one
	if level == "all":
		print("==== %s ====" % ("ALL LEVELS SOLVABLE" if all_pass else "SOME LEVELS FAILED"))
	quit(0 if all_pass else 1)


func _verify(level: String) -> bool:
	var steps: Array = SOLUTIONS.get(level, [])
	var game: Node = load("res://scenes/game/game.tscn").instantiate()
	game.set("initial_level_path", "res://levels/%s.tscn" % level)
	root.add_child(game)
	await process_frame
	var step_i := 0
	var frame := 0
	while frame < MAX_FRAMES:
		frame += 1
		while step_i < steps.size() and int(steps[step_i].get("f", 0)) <= frame:
			_apply(game, steps[step_i])
			step_i += 1
		if _gm.current_state == ST_RESULT:
			break
		await physics_frame
	var req := 0
	var lvl = game.get("current_level")
	if lvl:
		req = int(lvl.get("save_required"))
	var saved := int(_gm.saved_count)
	var win: bool = saved >= req and req > 0 and _gm.current_state == ST_RESULT
	print("%s : saved=%d/%d dead=%d  ==> %s" % [
		level, saved, req, int(_gm.dead_count), ("WIN" if win else "FAIL")])
	if OS.get_cmdline_args().has("--debug-stuck"):
		for n in root.get_tree().get_nodes_in_group("lemmings"):
			print("  lem @ ", n.global_position, " state=", n.get("current_state"))
	game.queue_free()
	await process_frame
	_gm.reset()
	return win


func _apply(game: Node, s: Dictionary) -> void:
	var sm = game.get("skill_manager")
	if sm == null or not sm.select_skill(str(s.get("skill", ""))):
		return
	var target := Vector2(float(s.get("x", 0)), float(s.get("y", 0)))
	var best = null
	var best_d := 1e20
	for n in root.get_tree().get_nodes_in_group("lemmings"):
		var d: float = n.global_position.distance_to(target)
		if d < best_d:
			best_d = d
			best = n
	if best != null:
		sm.assign_to(best)
