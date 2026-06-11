extends Panel

# Overview map of the whole level, drawn in a HUD corner. Shows a terrain
# silhouette (built once when the level loads), live lemming dots, the entrance
# and exit, and a rectangle marking the camera's current view. Tapping anywhere
# on it re-centres the camera there — handy on big levels where the zoomed-in
# main view only shows a slice.

const MAX_W: float = 150.0
const MAX_H: float = 110.0
const DIRT_COL := Color(0.55, 0.40, 0.18)
const STEEL_COL := Color(0.62, 0.62, 0.68)
const LEM_COL := Color(1, 1, 1)
const ENTRANCE_COL := Color(0.45, 0.7, 1.0)
const EXIT_COL := Color(0.3, 0.9, 0.4)
const VIEW_COL := Color(1.0, 0.85, 0.2)

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
	# Sample the pixel terrain on an 8px grid — twice the detail the old
	# tile-based silhouette had, cheap enough to build once per level.
	const STEP: int = 8
	var cols: int = maxi(1, int(_bounds.size.x) / STEP)
	var rows: int = maxi(1, int(_bounds.size.y) / STEP)
	var img := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for ty in range(rows):
		for tx in range(cols):
			var wp := Vector2(
				_bounds.position.x + (tx + 0.5) * STEP,
				_bounds.position.y + (ty + 0.5) * STEP)
			if _level.has_method("is_steel_px") and _level.is_steel_px(wp):
				img.set_pixel(tx, ty, STEEL_COL)
			elif _level.has_method("is_solid_px") and _level.is_solid_px(wp):
				img.set_pixel(tx, ty, DIRT_COL)
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
