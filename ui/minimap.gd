extends Panel

# Overview map of the whole level, drawn in a HUD corner. Shows a terrain
# silhouette (built once when the level loads), live lemming dots, the entrance
# and exit, and a rectangle marking the camera's current view. Tapping anywhere
# on it re-centres the camera there — handy on big levels where the zoomed-in
# main view only shows a slice.

const MAX_W: float = 150.0
const MAX_H: float = 110.0
const STEEL_COL := Color(0.62, 0.62, 0.68)
const LEM_COL := Color(1, 1, 1)
const ENTRANCE_COL := Color(0.45, 0.7, 1.0)
const EXIT_COL := Color(0.3, 0.9, 0.4)
const VIEW_COL := Color(1.0, 0.85, 0.2)
# Per-theme {surface cap colour, buried-rock colour} — so the minimap reads as
# the level's biome instead of one flat brown. Surface cells (open sky above)
# take the cap colour; deeper cells the rock colour, with a little noise so the
# fill has texture rather than being a solid block.
const THEME_COLS := {
	"dirt":    [Color(0.50, 0.78, 0.30), Color(0.46, 0.33, 0.17)],
	"fire":    [Color(1.00, 0.70, 0.25), Color(0.50, 0.18, 0.06)],
	"inferno": [Color(1.00, 0.55, 0.15), Color(0.30, 0.09, 0.05)],
	"marble":  [Color(0.88, 0.90, 0.95), Color(0.45, 0.47, 0.55)],
	"crystal": [Color(0.55, 0.92, 1.00), Color(0.28, 0.20, 0.55)],
}
const HAZARD_COLS := {"water": Color(0.25, 0.55, 1.0, 0.7), "fire": Color(1.0, 0.4, 0.1, 0.7)}

var _level: Node = null
var _camera: Node = null
var _bounds: Rect2 = Rect2()
var _thumb: ImageTexture = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)
	visible = false


# Called by the HUD/game once a level is loaded. Builds the static terrain
# thumbnail and starts live redraws.
func bind(level: Node, camera: Node) -> void:
	_level = level
	_camera = camera
	if level == null or not level.has_method("get_terrain_bounds_px"):
		visible = false
		return
	_bounds = level.get_terrain_bounds_px()
	if not _bounds.has_area():
		visible = false
		return
	_build_thumbnail()
	_fit_size()
	visible = true
	set_process(true)


func _fit_size() -> void:
	# Keep the level's aspect ratio within the max footprint.
	var aspect: float = _bounds.size.x / maxf(1.0, _bounds.size.y)
	var w: float = MAX_W
	var h: float = w / maxf(0.01, aspect)
	if h > MAX_H:
		h = MAX_H
		w = h * aspect
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)


func _build_thumbnail() -> void:
	# Sample the pixel terrain on a 6px grid for readable relief: surface cells
	# (sky directly above) take the theme's cap colour, buried cells the rock
	# colour shaded by a touch of noise, steel its own grey.
	const STEP: int = 6
	var cols: int = maxi(1, int(_bounds.size.x) / STEP)
	var rows: int = maxi(1, int(_bounds.size.y) / STEP)
	var theme: String = str(_level.get("terrain_theme")) if _level else "dirt"
	var pair: Array = THEME_COLS.get(theme, THEME_COLS["dirt"])
	var cap: Color = pair[0]
	var rock: Color = pair[1]
	var img := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for ty in range(rows):
		for tx in range(cols):
			var wp := Vector2(
				_bounds.position.x + (tx + 0.5) * STEP,
				_bounds.position.y + (ty + 0.5) * STEP)
			if not (_level.has_method("is_solid_px") and _level.is_solid_px(wp)):
				continue
			if _level.has_method("is_steel_px") and _level.is_steel_px(wp):
				img.set_pixel(tx, ty, STEEL_COL)
				continue
			# Open sky one step up → this is a surface/grass cap.
			var above := Vector2(wp.x, wp.y - STEP)
			var col: Color = cap if not _level.is_solid_px(above) else rock
			# Subtle deterministic shading so the fill has texture, not a slab.
			var n: float = float((tx * 131 + ty * 709) % 100) / 100.0
			col = col.lightened(0.08 * n).darkened(0.06 * (1.0 - n))
			img.set_pixel(tx, ty, col)
	_thumb = ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _thumb == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	# Dark backing so transparent (empty) areas read as sky, with the silhouette
	# on top.
	draw_rect(rect, Color(0.05, 0.05, 0.10, 0.85))
	draw_texture_rect(_thumb, rect, false)
	# Hazard zones (water / fire) as translucent patches, so dangers are visible
	# on the overview.
	for hz in get_tree().get_nodes_in_group("hazards"):
		if not hz.has_method("rect_px"):
			continue
		var r: Rect2 = hz.rect_px()
		# HazardType enum: WATER = 0, FIRE = 1.
		var tname: String = "water" if ("hazard_type" in hz and int(hz.hazard_type) == 0) else "fire"
		var mini := Rect2(_to_mini(r.position), r.size * _scale())
		draw_rect(mini, HAZARD_COLS.get(tname, HAZARD_COLS["fire"]))
	# Traps as small red diamonds.
	for tp in get_tree().get_nodes_in_group("traps"):
		if tp is Node2D:
			draw_circle(_to_mini((tp as Node2D).global_position), 2.0, Color(1.0, 0.3, 0.3))
	# Entrance / exit markers.
	var ent = _level.get("entrance")
	if ent != null:
		draw_rect(Rect2(_to_mini(ent.global_position) - Vector2(2, 2), Vector2(4, 4)), ENTRANCE_COL)
	var ex = _level.get("level_exit")
	if ex != null:
		draw_rect(Rect2(_to_mini(ex.global_position) - Vector2(2, 2), Vector2(4, 4)), EXIT_COL)
	# Live lemmings.
	for n in get_tree().get_nodes_in_group("lemmings"):
		draw_circle(_to_mini(n.global_position), 1.5, LEM_COL)
	# Current camera view rectangle.
	if _camera != null and _camera.has_method("visible_world_rect"):
		var vr: Rect2 = _camera.visible_world_rect()
		var mini := Rect2(_to_mini(vr.position), vr.size * _scale())
		draw_rect(mini, VIEW_COL, false, 1.5)


func _to_mini(world_pos: Vector2) -> Vector2:
	return (world_pos - _bounds.position) * _scale()


func _scale() -> Vector2:
	return Vector2(size.x / maxf(1.0, _bounds.size.x), size.y / maxf(1.0, _bounds.size.y))


func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.INF
	if event is InputEventMouseButton and event.pressed:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventScreenDrag:
		pos = event.position
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		pos = event.position
	if pos == Vector2.INF:
		return
	if _camera != null and _camera.has_method("center_on"):
		var world: Vector2 = _bounds.position + pos / _scale()
		_camera.center_on(world)
	accept_event()
