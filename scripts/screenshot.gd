extends SceneTree
# Dev tool: boot a level in the real game scene, wait for it to render, save a
# PNG of the viewport and quit. Needs a window (the terrain shader runs on GPU):
#   godot --fixed-fps 60 -s scripts/screenshot.gd -- --level=fun/level_01 --out=/tmp/shot.png [--frames=90]

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var level := "fun/level_01"
	var out := "/tmp/shot.png"
	var frames := 90
	var zoom := 0.0
	var focus := Vector2.INF
	var all_args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for a in all_args:
		if a.begins_with("--level="):
			level = a.substr("--level=".length())
		elif a.begins_with("--out="):
			out = a.substr("--out=".length())
		elif a.begins_with("--frames="):
			frames = int(a.substr("--frames=".length()))
		elif a.begins_with("--zoom="):
			zoom = float(a.substr("--zoom=".length()))
		elif a.begins_with("--focus="):
			var parts := a.substr("--focus=".length()).split(",")
			if parts.size() == 2:
				focus = Vector2(float(parts[0]), float(parts[1]))
	var assign := ""   # "skill,x,y,frame" — assign a skill mid-run (e.g. builder)
	for a in all_args:
		if a.begins_with("--assign="):
			assign = a.substr("--assign=".length())
	var game: Node = (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	game.set("initial_level_path", "res://levels/%s.tscn" % level)
	root.add_child(game)
	var ap := assign.split(",")
	for f in range(frames):
		if ap.size() == 4 and f == int(ap[3]):
			var sm = game.get("skill_manager")
			if sm != null and sm.select_skill(ap[0]):
				var target := Vector2(float(ap[1]), float(ap[2]))
				var best = null
				var best_d := 1e20
				for n in root.get_tree().get_nodes_in_group("lemmings"):
					var d: float = n.global_position.distance_to(target)
					if d < best_d:
						best_d = d
						best = n
				if best != null:
					sm.assign_to(best)
		await process_frame
	var cam = game.get("camera")
	if cam != null and zoom > 0.0:
		cam.set_zoom_level(zoom)
	if cam != null and focus != Vector2.INF:
		cam.center_on(focus)
	if zoom > 0.0 or focus != Vector2.INF:
		for f in range(5):
			await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	quit(0)
