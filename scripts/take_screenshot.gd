extends SceneTree

# Headless level-screenshot tool.
# Loads a procedural level scene, advances N frames so lemmings spawn and walk,
# then captures the root viewport as a PNG.
#
# Usage:
#   xvfb-run -a -s "-screen 0 1280x720x24" ./godot \
#       -s scripts/take_screenshot.gd \
#       --level=level_01 --output=screenshots/level_01.png --frame=60
#
# Optional flags (defaults in brackets):
#   --level=level_01         [level_01]
#   --difficulty=fun         [fun]
#   --output=screenshots/<level>.png
#   --frame=60               number of physics frames to simulate

const DEFAULT_FRAME: int = 60
const DEFAULT_DIFFICULTY: String = "fun"


func _init() -> void:
	var level_name: String = "level_01"
	var output_path: String = ""
	var target_frame: int = DEFAULT_FRAME
	var difficulty: String = DEFAULT_DIFFICULTY

	for arg in OS.get_cmdline_args():
		if arg.begins_with("--level="):
			level_name = arg.substr("--level=".length())
		elif arg.begins_with("--output="):
			output_path = arg.substr("--output=".length())
		elif arg.begins_with("--frame="):
			target_frame = int(arg.substr("--frame=".length()))
		elif arg.begins_with("--difficulty="):
			difficulty = arg.substr("--difficulty=".length())

	if output_path == "":
		output_path = "screenshots/%s.png" % level_name

	# Defer to the main loop so the SceneTree is fully initialised before we
	# start adding children and awaiting frames.
	_run.call_deferred(level_name, output_path, target_frame, difficulty)


func _run(level_name: String, output_path: String, target_frame: int, difficulty: String) -> void:
	var scene_path: String = "res://levels/%s/%s.tscn" % [difficulty, level_name]
	if not ResourceLoader.exists(scene_path):
		push_error("Scene not found: %s" % scene_path)
		quit(1)
		return
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("Failed to load scene: %s" % scene_path)
		quit(1)
		return

	var level_node: Node = packed.instantiate()
	root.add_child(level_node)

	# Wake the GameManager autoload (if present) so the entrance starts spawning.
	var gm: Node = root.get_node_or_null("GameManager")
	if gm and gm.has_method("start_level"):
		gm.start_level(level_name)

	# Let the scene tree settle for a frame before simulating.
	await process_frame

	for _i in target_frame:
		await physics_frame

	# One extra render frame so the viewport reflects the latest state.
	await process_frame

	var viewport: Viewport = root.get_viewport()
	var tex: ViewportTexture = viewport.get_texture()
	var img: Image = tex.get_image() if tex else null
	if img == null:
		push_error("Failed to read viewport image (rendering disabled?)")
		quit(1)
		return

	var out_dir: String = output_path.get_base_dir()
	if out_dir != "" and not DirAccess.dir_exists_absolute(out_dir):
		var mk_err: int = DirAccess.make_dir_recursive_absolute(out_dir)
		if mk_err != OK:
			push_error("mkdir failed for %s: %d" % [out_dir, mk_err])
			quit(1)
			return

	var err: int = img.save_png(output_path)
	if err != OK:
		push_error("save_png failed: %d" % err)
		quit(1)
		return

	print("Saved screenshot: %s (%dx%d)" % [output_path, img.get_width(), img.get_height()])
	quit(0)
