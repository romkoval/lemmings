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
	var scene := ""    # arbitrary scene instead of the game (e.g. the editor)
	for a in all_args:
		if a.begins_with("--assign="):
			assign = a.substr("--assign=".length())
		elif a.begins_with("--scene="):
			scene = a.substr("--scene=".length())
	var edit_path := ""   # open the editor with this level loaded
	var paint := false    # demo brush strokes in the editor
	for a in all_args:
		if a.begins_with("--edit="):
			edit_path = a.substr("--edit=".length())
		elif a == "--paint":
			paint = true
	var game: Node
	if scene != "":
		if edit_path != "":
			root.get_node("/root/LevelManager").set("editing_path", edit_path)
		game = (load(scene) as PackedScene).instantiate()
	else:
		game = (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
		var lp: String = level if level.begins_with("user://") else "res://levels/%s.tscn" % level
		game.set("initial_level_path", lp)
	root.add_child(game)
	if paint and game.has_method("_stroke_at"):
		await process_frame
		# A rolling hill, a floating platform and a steel slab, hand-drawn.
		game.set("brush_radius", 24.0)
		for i in range(40):
			var x := 60.0 + i * 16.0
			game.call("_stroke_at", Vector2(x, 1050.0 + 60.0 * sin(i * 0.25)))
		game.set("brush_radius", 12.0)
		game.set("tool", 1)  # STEEL
		game.set("_last_stroke", Vector2.INF)
		for i in range(8):
			game.call("_stroke_at", Vector2(120.0 + i * 14.0, 1150.0))
		game.set("tool", 0)  # DIRT back
		game.set("_last_stroke", Vector2.INF)
		for i in range(10):
			game.call("_stroke_at", Vector2(420.0 + i * 12.0, 760.0))
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
