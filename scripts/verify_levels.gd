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
	# ── Tricky: the new objects (water/fire/traps/one-way walls) in play ──
	# Walk calibration: the leader's feet_x ≈ frame + 61 (spawn lag included).
	"tricky/level_01": [  # bridge over the water; the exit sits on the stair path
		{"f": 222, "skill": "builder", "x": 291, "y": 455},
	],
	"tricky/level_02": [  # dig through the floor into the gallery under the fire
		{"f": 187, "skill": "digger", "x": 256, "y": 455},
	],
	"tricky/level_03": [],  # trap gauntlet: the dense crowd walks it
	"tricky/level_04": [  # one-way wall pointing along travel: bash through
		{"f": 249, "skill": "basher", "x": 312, "y": 455},
	],
	"tricky/level_05": [  # block the crowd, bridge, then bomb the blocker
		{"f": 130, "skill": "blocker", "x": 79, "y": 448},
		{"f": 222, "skill": "builder", "x": 291, "y": 455},
		{"f": 700, "skill": "bomber", "x": 110, "y": 448},
	],
	"tricky/level_06": [  # mine a diagonal tunnel off the plateau
		{"f": 199, "skill": "miner", "x": 260, "y": 360},
	],
	"tricky/level_07": [  # one tall stairway over the fire lake to the ledge
		{"f": 251, "skill": "builder", "x": 320, "y": 455},
	],
	"tricky/level_08": [  # steel cap guards the left — dig past its edge
		{"f": 419, "skill": "digger", "x": 488, "y": 455},
	],
	"tricky/level_09": [  # bash the arrow wall, then bridge over the fire
		{"f": 225, "skill": "basher", "x": 290, "y": 455},
		{"f": 377, "skill": "builder", "x": 398, "y": 455},
	],
	"tricky/level_10": [  # dig into the gallery, bash the arrows, pass the clamp
		{"f": 187, "skill": "digger", "x": 256, "y": 455},
		{"f": 485, "skill": "basher", "x": 470, "y": 517},
	],
	# ── Taxing: the inferno ascent. A blocker pens the crowd by the hatch while
	# the leader stairs over the lava lake onto the hanging bridge, bashes the
	# one-way gate, stairs again to the top shelf — then a bomber frees the mob.
	"taxing/level_01": [
		{"f": 165, "skill": "blocker", "x": 122, "y": 462},
		{"f": 491, "skill": "builder", "x": 552, "y": 462},
		{"f": 1229, "skill": "basher", "x": 916, "y": 300},
		{"f": 1526, "skill": "builder", "x": 1160, "y": 302},
		{"f": 2120, "skill": "bomber", "x": 135, "y": 462},
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
	# Death log (--debug-stuck): cause + position of every death, for authoring.
	if OS.get_cmdline_args().has("--debug-stuck"):
		var lvl_node = game.get("current_level")
		if lvl_node and lvl_node.get("entrance") != null:
			lvl_node.entrance.lemming_spawned.connect(func(lem):
				lem.lemming_died.connect(func(l, cause):
					print("  died: %s @ %s" % [cause, l.global_position])))
	var step_i := 0
	var frame := 0
	var trace: bool = OS.get_cmdline_args().has("--trace")
	while frame < MAX_FRAMES:
		frame += 1
		while step_i < steps.size() and int(steps[step_i].get("f", 0)) <= frame:
			_apply(game, steps[step_i])
			step_i += 1
		if _gm.current_state == ST_RESULT:
			break
		# Leader trace (--trace): the frontmost lemming every 60 frames — for
		# calibrating solution frames against the actual walk.
		if trace and frame % 60 == 0:
			var front = null
			for n in root.get_tree().get_nodes_in_group("lemmings"):
				if front == null or n.global_position.x > front.global_position.x:
					front = n
			if front:
				print("  f%d front @ %s state=%s" % [frame, front.global_position, front.get("current_state")])
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
		if lvl and lvl.has_method("rect_blocks_carve_px"):
			var gate := Rect2i(917, 287, 16, 17)
			print("  gate blocks(+1)=", lvl.rect_blocks_carve_px(gate, 1),
				" blocks(-1)=", lvl.rect_blocks_carve_px(gate, -1),
				" steel929=", lvl.is_steel_px(Vector2(929.5, 295.5)),
				" ow929=", lvl.oneway_dir_px(Vector2(929.5, 295.5)),
				" ow917=", lvl.oneway_dir_px(Vector2(917.5, 295.5)),
				" solid917=", lvl.is_solid_px(Vector2(917.5, 295.5)))
		# Surface profile around the first stuck lemming: topmost solid y per
		# column — phantom walls and unexpected steps show up as jumps.
		var stuck: Array = root.get_tree().get_nodes_in_group("lemmings")
		if lvl and not stuck.is_empty():
			var cx: int = int(stuck[0].global_position.x)
			var line: String = ""
			for px in range(cx - 120, cx + 200, 8):
				var top: int = -1
				for py in range(60, 600, 4):
					if lvl.is_solid_px(Vector2(px + 0.5, py + 0.5)):
						top = py
						break
				line += "%d:%d " % [px, top]
			print("  surface: ", line)
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
		var ok: bool = sm.assign_to(best)
		if OS.get_cmdline_args().has("--debug-stuck"):
			print("  assign %s -> %s @ %s (target %s) %s" % [
				s.get("skill"), best.name, best.global_position, target, "OK" if ok else "REFUSED"])
