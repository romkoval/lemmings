class_name LevelEditor
extends Node2D

# In-game level editor, WYSIWYG with the pixel world: the canvas IS a live
# PixelTerrain rendered by the same shader the game uses, and the brushes
# paint/erase pixels in the same mask the physics reads. What you draw is —
# bit for bit — what plays.
#
# Terrain is saved as mask/material PNGs next to the level JSON in
# user://custom_levels/; played levels load the images straight into
# PixelTerrain (no tiles, no smoothing, no translation losses).
#
# Input: one finger / LMB paints with the active brush; two fingers pinch-zoom
# and pan; mouse wheel zooms, right/middle drag pans.

const SCREEN_PX := Vector2i(720, 1280)
const MAX_SCREENS_W: int = 4
const MAX_SCREENS_H: int = 3

enum Tool { DIRT, STEEL, ERASE, ENTRANCE, EXIT, WATER, FIRE, TRAP_CRUSHER, TRAP_CLAMP, ONEWAY_R, ONEWAY_L }

const TOOL_LABELS: Dictionary = {
	Tool.DIRT: "Грунт",
	Tool.STEEL: "Сталь",
	Tool.ERASE: "Ластик",
	Tool.ENTRANCE: "Вход",
	Tool.EXIT: "Выход",
	Tool.WATER: "Вода",
	Tool.FIRE: "Огонь",
	Tool.TRAP_CRUSHER: "Пресс",
	Tool.TRAP_CLAMP: "Капкан",
	Tool.ONEWAY_R: "Стена →",
	Tool.ONEWAY_L: "Стена ←",
}
const BRUSH_SIZES: Array = [6.0, 12.0, 24.0]
const BRUSH_LABELS: Array = ["⏺", "⬤", "⚫"]

const SKILL_KEYS: Array = [
	"climber", "floater", "bomber", "blocker", "builder", "basher", "miner", "digger"]
const SKILL_LABELS: Dictionary = {
	"climber": "Альпинист", "floater": "Парашютист", "bomber": "Бомбер",
	"blocker": "Блокер", "builder": "Строитель", "basher": "Долбильщик",
	"miner": "Шахтёр", "digger": "Копатель",
}

@onready var entrance: Node2D = $World/Entrance
@onready var level_exit: Node2D = $World/LevelExit
@onready var camera: Camera2D = $Camera2D

var terrain: PixelTerrain = null
# Canvas size in screens (720×1280 each) — levels can span several screens.
var screens_w: int = 1
var screens_h: int = 1

var tool: Tool = Tool.DIRT
var brush_radius: float = 12.0
var level_name: String = "Мой уровень"
var level_id: String = ""
var save_path: String = ""
var total_lemmings: int = 10
var save_required: int = 5
var time_limit: int = 300
var release_rate: int = 50
var skill_counts: Dictionary = {}

var hazards: Array = []   # HazardZone nodes living in $World, saved with the level
var traps: Array = []     # Trap nodes living in $World, saved with the level

var _has_content: bool = false
var _painting: bool = false
var _active_hazard: HazardZone = null   # the zone being dragged out right now
var _hazard_anchor: Vector2 = Vector2.ZERO
var _active_trap: Trap = null           # the trap being placed/moved right now
var _last_stroke: Vector2 = Vector2.INF
var _cursor_world: Vector2 = Vector2.INF
var _touches: Dictionary = {}
var _gesture: bool = false
var _pinch_start_dist: float = 0.0
var _pinch_start_zoom: float = 1.0
var _pan_last: Vector2 = Vector2.ZERO
var _mouse_panning: bool = false

var _params_panel: PanelContainer = null
var _name_edit: LineEdit = null
var _spins: Dictionary = {}
var _toast: Label = null


func _ready() -> void:
	GameManager.set_state(GameManager.GameState.MENU)
	for k in SKILL_KEYS:
		skill_counts[k] = 2
	_init_blank_canvas()
	_build_ui()
	_refresh_camera()
	# Returning from a test run (or opening an existing level from the browser).
	if LevelManager.editing_path != "":
		_load_from(LevelManager.editing_path)
	queue_redraw()


func canvas_px() -> Vector2i:
	return Vector2i(SCREEN_PX.x * screens_w, SCREEN_PX.y * screens_h)


# An all-air pixel canvas of the current size, with live grass preview (what
# you paint is the "natural" surface).
func _init_blank_canvas() -> void:
	if terrain != null:
		terrain.queue_free()
	terrain = PixelTerrain.new()
	terrain.name = "Canvas"
	terrain.live_grass = true
	$World.add_child(terrain)
	$World.move_child(terrain, 0)
	terrain.build_blank(Rect2i(Vector2i.ZERO, canvas_px()))
	_has_content = false


# Change the canvas size in screens, keeping everything already painted (pixels
# stay at their world positions; shrinking crops).
func _set_canvas_screens(w: int, h: int) -> void:
	w = clampi(w, 1, MAX_SCREENS_W)
	h = clampi(h, 1, MAX_SCREENS_H)
	if w == screens_w and h == screens_h:
		return
	screens_w = w
	screens_h = h
	var old: Dictionary = terrain.export_images()
	var had_content: bool = _has_content
	_init_blank_canvas()
	terrain.blit_from(old["mask"], old["mat"], old["origin"])
	_has_content = had_content
	_refresh_camera()
	queue_redraw()


func _refresh_camera() -> void:
	camera.setup_bounds(self, Vector2(canvas_px()) * 0.5)
	camera.set_zoom_level(1.0)


# camera_controller asks the bound node for pan bounds — the editor's canvas.
func get_terrain_bounds_px() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(canvas_px()))


func _process(_delta: float) -> void:
	queue_redraw()   # brush cursor follows the pointer


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(canvas_px())), Color(1, 1, 1, 0.35), false, 2.0)
	# Faint screen-size guides inside multi-screen canvases.
	for sx in range(1, screens_w):
		draw_line(Vector2(sx * SCREEN_PX.x, 0), Vector2(sx * SCREEN_PX.x, canvas_px().y), Color(1, 1, 1, 0.12))
	for sy in range(1, screens_h):
		draw_line(Vector2(0, sy * SCREEN_PX.y), Vector2(canvas_px().x, sy * SCREEN_PX.y), Color(1, 1, 1, 0.12))
	if _cursor_world != Vector2.INF and tool in [Tool.DIRT, Tool.STEEL, Tool.ERASE, Tool.ONEWAY_R, Tool.ONEWAY_L]:
		var col := Color(1, 1, 1, 0.6)
		if tool == Tool.STEEL:
			col = Color(0.7, 0.75, 0.85, 0.8)
		elif tool == Tool.ERASE:
			col = Color(1.0, 0.5, 0.4, 0.8)
		elif tool in [Tool.ONEWAY_R, Tool.ONEWAY_L]:
			col = Color(0.93, 0.78, 0.2, 0.8)
		draw_arc(_cursor_world, brush_radius, 0.0, TAU, 40, col, 1.5)


# ── Painting ─────────────────────────────────────────────────────────────────

func _stroke_at(world: Vector2) -> void:
	var cpx := canvas_px()
	var p := Vector2(clampf(world.x, 0, cpx.x), clampf(world.y, 0, cpx.y))
	match tool:
		Tool.ENTRANCE:
			entrance.position = p.round()
			return
		Tool.EXIT:
			level_exit.position = p.round()
			return
		Tool.WATER, Tool.FIRE:
			# Drag out a rectangle: the press anchors a corner, the drag pulls
			# the opposite one. Releasing the pointer finalizes the zone.
			var htype := HazardZone.HazardType.WATER if tool == Tool.WATER else HazardZone.HazardType.FIRE
			if _active_hazard == null:
				_hazard_anchor = p
				_active_hazard = _add_hazard(htype, Rect2(p, HazardZone.MIN_SIZE))
			else:
				var hr := Rect2(_hazard_anchor, Vector2.ZERO).expand(p).abs()
				_active_hazard.position = hr.position
				_active_hazard.zone_size = hr.size
			_last_stroke = p
			return
		Tool.TRAP_CRUSHER, Tool.TRAP_CLAMP:
			# Press drops a trap centred under the finger; dragging fine-tunes
			# its position until release.
			var ttype := Trap.TrapType.CRUSHER if tool == Tool.TRAP_CRUSHER else Trap.TrapType.CLAMP
			var at: Vector2 = (p - Trap.TRIGGER_SIZE * 0.5).round()
			if _active_trap == null:
				_active_trap = _add_trap(ttype, at)
			else:
				_active_trap.position = at
			_last_stroke = p
			return
		_:
			pass
	# Brush stroke: stamp circles from the last point to this one so fast drags
	# leave a continuous band, not dotted blobs.
	var from := p if _last_stroke == Vector2.INF else _last_stroke
	var dist := from.distance_to(p)
	var steps: int = maxi(1, int(ceilf(dist / maxf(brush_radius * 0.4, 2.0))))
	for i in range(1, steps + 1):
		var q := from.lerp(p, float(i) / float(steps))
		match tool:
			Tool.DIRT:
				terrain.fill_circle(q, brush_radius, PixelTerrain.MAT_DIRT, true)
				_has_content = true
			Tool.STEEL:
				terrain.fill_circle(q, brush_radius, PixelTerrain.MAT_STEEL, true)
				_has_content = true
			Tool.ONEWAY_R:
				terrain.fill_circle(q, brush_radius, PixelTerrain.MAT_ONEWAY_R, true)
				_has_content = true
			Tool.ONEWAY_L:
				terrain.fill_circle(q, brush_radius, PixelTerrain.MAT_ONEWAY_L, true)
				_has_content = true
			Tool.ERASE:
				terrain.carve_circle(q, brush_radius, true)
				_erase_hazards_at(q)
	_last_stroke = p


func _add_hazard(htype: HazardZone.HazardType, rect: Rect2) -> HazardZone:
	var zone := HazardZone.new()
	zone.hazard_type = htype
	zone.position = rect.position
	zone.zone_size = rect.size
	$World.add_child(zone)
	hazards.append(zone)
	return zone


func _add_trap(ttype: Trap.TrapType, at: Vector2) -> Trap:
	var trap := Trap.new()
	trap.trap_type = ttype
	trap.position = at
	$World.add_child(trap)
	traps.append(trap)
	return trap


# The eraser doubles as the hazard/trap remover — any stamp landing on a zone
# or trap deletes the whole object (they are placed objects, not pixels).
func _erase_hazards_at(p: Vector2) -> void:
	for hz in hazards.duplicate():
		if (hz as HazardZone).rect_px().grow(brush_radius * 0.5).has_point(p):
			hazards.erase(hz)
			hz.queue_free()
	for tr in traps.duplicate():
		if (tr as Trap).rect_px().grow(brush_radius * 0.5).has_point(p):
			traps.erase(tr)
			tr.queue_free()


# ── Input: paint / pan / zoom ────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
			if _touches.size() == 1:
				_painting = true
				_last_stroke = Vector2.INF
				_stroke_at(_screen_to_world(st.position))
			else:
				_painting = false
				_gesture = true
				_start_pinch()
		else:
			_touches.erase(st.index)
			if _touches.is_empty():
				_painting = false
				_gesture = false
				_active_hazard = null
				_active_trap = null
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		_cursor_world = _screen_to_world(sd.position)
		if _gesture and _touches.size() >= 2:
			_update_pinch()
		elif _painting:
			_stroke_at(_cursor_world)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_painting = mb.pressed
			if mb.pressed:
				_last_stroke = Vector2.INF
				_stroke_at(get_global_mouse_position())
			else:
				_active_hazard = null
				_active_trap = null
		elif mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_mouse_panning = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			camera.zoom_by(1.1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			camera.zoom_by(1.0 / 1.1)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_cursor_world = get_global_mouse_position()
		if _mouse_panning:
			camera.pan_screen(mm.relative)
		elif _painting:
			_stroke_at(_cursor_world)


func _screen_to_world(screen: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen


func _start_pinch() -> void:
	var pts: Array = _touches.values()
	if pts.size() < 2:
		return
	_pinch_start_dist = (pts[0] as Vector2).distance_to(pts[1])
	_pinch_start_zoom = camera.zoom.x
	_pan_last = ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5


func _update_pinch() -> void:
	var pts: Array = _touches.values()
	if pts.size() < 2:
		return
	var centroid: Vector2 = ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5
	camera.pan_screen(centroid - _pan_last)
	_pan_last = centroid
	var dist: float = (pts[0] as Vector2).distance_to(pts[1])
	if _pinch_start_dist > 1.0:
		camera.set_zoom_level(_pinch_start_zoom * dist / _pinch_start_dist)


# ── Save / load / test ───────────────────────────────────────────────────────

func _collect_meta() -> Dictionary:
	if level_id == "":
		level_id = "custom_%d" % (Time.get_unix_time_from_system() as int)
	return {
		"id": level_id,
		"name": level_name,
		"custom": true,
		"total_lemmings": total_lemmings,
		"save_required": save_required,
		"time_limit": time_limit,
		"release_rate": release_rate,
		"skill_counts": skill_counts,
		"entrance_pos": [entrance.position.x, entrance.position.y],
		"entrance_direction": 1,
		"exit_pos": [level_exit.position.x, level_exit.position.y],
		"terrain_mask": level_id + "_mask.png",
		"terrain_mat": level_id + "_mat.png",
		"terrain_origin": [terrain.bounds_px().position.x, terrain.bounds_px().position.y],
		"playfield": [0, 0, canvas_px().x, canvas_px().y],
		"hazards": hazards.map(func(h): return {
			"type": HazardZone.TYPE_NAMES[(h as HazardZone).hazard_type],
			"rect": [h.position.x, h.position.y, h.zone_size.x, h.zone_size.y],
		}),
		"traps": traps.map(func(t): return {
			"type": Trap.TYPE_NAMES[(t as Trap).trap_type],
			"pos": [t.position.x, t.position.y],
		}),
	}


func _load_from(path: String) -> void:
	var d: Dictionary = LevelManager.load_level_json(path)
	if d.is_empty():
		return
	save_path = path
	level_id = str(d.get("id", ""))
	level_name = str(d.get("name", level_name))
	total_lemmings = int(d.get("total_lemmings", total_lemmings))
	save_required = int(d.get("save_required", save_required))
	time_limit = int(d.get("time_limit", time_limit))
	release_rate = int(d.get("release_rate", release_rate))
	var sk = d.get("skill_counts", null)
	if sk is Dictionary:
		for k in SKILL_KEYS:
			skill_counts[k] = int(sk.get(k, 0))
	var ep = d.get("entrance_pos", null)
	if ep is Array and ep.size() == 2:
		entrance.position = Vector2(float(ep[0]), float(ep[1]))
	var xp = d.get("exit_pos", null)
	if xp is Array and xp.size() == 2:
		level_exit.position = Vector2(float(xp[0]), float(xp[1]))
	var pf = d.get("playfield", null)
	if pf is Array and pf.size() == 4:
		screens_w = clampi(int(float(pf[2]) / SCREEN_PX.x), 1, MAX_SCREENS_W)
		screens_h = clampi(int(float(pf[3]) / SCREEN_PX.y), 1, MAX_SCREENS_H)
		_init_blank_canvas()
		_refresh_camera()
	for hz in hazards:
		hz.queue_free()
	hazards.clear()
	_active_hazard = null
	for hz in d.get("hazards", []):
		if hz is Dictionary and hz.get("rect", null) is Array and (hz["rect"] as Array).size() == 4:
			var hr: Array = hz["rect"]
			_add_hazard(HazardZone.type_from_name(str(hz.get("type", "water"))),
				Rect2(float(hr[0]), float(hr[1]), float(hr[2]), float(hr[3])))
	for tr in traps:
		tr.queue_free()
	traps.clear()
	_active_trap = null
	for tr in d.get("traps", []):
		if tr is Dictionary and tr.get("pos", null) is Array and (tr["pos"] as Array).size() == 2:
			var tp: Array = tr["pos"]
			_add_trap(Trap.type_from_name(str(tr.get("type", "crusher"))),
				Vector2(float(tp[0]), float(tp[1])))
	_load_terrain(d, path.get_base_dir())


func _load_terrain(d: Dictionary, dir: String) -> void:
	# Preferred: painted mask/material images (exact WYSIWYG round-trip).
	var mask_name: String = str(d.get("terrain_mask", ""))
	if mask_name != "":
		var mask_img := _load_png(dir + "/" + mask_name)
		if mask_img != null:
			var mat_img := _load_png(dir + "/" + str(d.get("terrain_mat", "")))
			var org = d.get("terrain_origin", null)
			var origin := Vector2i(-320, -384)
			if org is Array and org.size() == 2:
				origin = Vector2i(int(org[0]), int(org[1]))
			terrain.build_from_images(mask_img, mat_img, origin)
			_has_content = true
			return
	# Legacy: tile lists from the first editor version — rasterize through the
	# same tile path the game uses (smoothing included) and continue in pixels.
	var tiles: Array = d.get("terrain_tiles", [])
	var steel: Array = d.get("steel", [])
	if tiles.is_empty() and steel.is_empty():
		return
	var tileset: TileSet = load("res://assets/tilesets/main_tileset.tres")
	var t := TileMapLayer.new()
	t.tile_set = tileset
	var s := TileMapLayer.new()
	s.tile_set = tileset
	for cell in tiles:
		if cell is Array and cell.size() >= 2:
			var atlas := Vector2i(1, 0)
			if cell.size() >= 4:
				atlas = Vector2i(int(cell[2]), int(cell[3]))
			t.set_cell(Vector2i(int(cell[0]), int(cell[1])), Level.DIRT_SOURCE, atlas)
	for cell in steel:
		if cell is Array and cell.size() == 2:
			s.set_cell(Vector2i(int(cell[0]), int(cell[1])), Level.STEEL_SOURCE, Vector2i.ZERO)
	terrain.build_from_tiles(t, s)
	t.free()
	s.free()
	_has_content = true


func _load_png(path: String) -> Image:
	if path.ends_with("/") or not FileAccess.file_exists(path):
		return null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		return null
	return img


func _save(show_toast: bool = true) -> bool:
	if not _has_content:
		_show_toast("Нарисуйте ландшафт перед сохранением")
		return false
	var meta: Dictionary = _collect_meta()   # assigns level_id
	if save_path == "":
		save_path = LevelManager.CUSTOM_LEVELS_DIR + level_id + ".json"
	LevelManager.ensure_custom_dir()
	var imgs: Dictionary = terrain.export_images()
	var dir: String = save_path.get_base_dir()
	var ok := true
	ok = (imgs["mask"] as Image).save_png(dir + "/" + str(meta["terrain_mask"])) == OK and ok
	ok = (imgs["mat"] as Image).save_png(dir + "/" + str(meta["terrain_mat"])) == OK and ok
	ok = LevelManager.save_level_json(save_path, meta) and ok
	if show_toast:
		_show_toast("Сохранено: %s" % level_name if ok else "Ошибка сохранения")
	return ok


func _test_play() -> void:
	if not _save(false):
		return
	LevelManager.editing_path = save_path
	var game_scene: PackedScene = load("res://scenes/game/game.tscn")
	var game := game_scene.instantiate()
	game.set("initial_level_path", save_path)
	GameManager.current_level_id = level_id
	get_tree().root.add_child(game)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = game


func _exit_to_browser() -> void:
	LevelManager.editing_path = ""
	get_tree().change_scene_to_file("res://scenes/menu/custom_levels.tscn")


# ── UI construction ─────────────────────────────────────────────────────────

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	# Top bar: back / title / params / test / save.
	var top := PanelContainer.new()
	top.anchor_right = 1.0
	top.offset_bottom = 64
	ui.add_child(top)
	var top_box := HBoxContainer.new()
	top_box.add_theme_constant_override("separation", 8)
	top.add_child(top_box)
	top_box.add_child(_mk_button("← Назад", _exit_to_browser))
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "Редактор"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	top_box.add_child(title)
	top_box.add_child(_mk_button("Параметры", _toggle_params))
	top_box.add_child(_mk_button("▶ Тест", _test_play))
	top_box.add_child(_mk_button("💾 Сохранить", func(): _save()))

	# Bottom bar: tools + brush sizes.
	var bottom := PanelContainer.new()
	bottom.anchor_top = 1.0
	bottom.anchor_right = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -84
	ui.add_child(bottom)
	# The tool row outgrew a portrait screen — let it scroll horizontally.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bottom.add_child(scroll)
	var tool_box := HBoxContainer.new()
	tool_box.alignment = BoxContainer.ALIGNMENT_CENTER
	tool_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tool_box.add_theme_constant_override("separation", 6)
	scroll.add_child(tool_box)
	var group := ButtonGroup.new()
	for t in TOOL_LABELS:
		var b := Button.new()
		b.text = TOOL_LABELS[t]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 60)
		b.add_theme_font_size_override("font_size", 20)
		b.button_pressed = (t == tool)
		b.toggled.connect(func(on: bool):
			if on:
				tool = t)
		tool_box.add_child(b)
	var sep := VSeparator.new()
	tool_box.add_child(sep)
	var brush_group := ButtonGroup.new()
	for i in BRUSH_SIZES.size():
		var b := Button.new()
		b.text = BRUSH_LABELS[i]
		b.toggle_mode = true
		b.button_group = brush_group
		b.custom_minimum_size = Vector2(56, 60)
		b.add_theme_font_size_override("font_size", 20)
		b.button_pressed = (BRUSH_SIZES[i] == brush_radius)
		var r: float = BRUSH_SIZES[i]
		b.toggled.connect(func(on: bool):
			if on:
				brush_radius = r)
		tool_box.add_child(b)

	_build_params_panel(ui)

	_toast = Label.new()
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_left = -250
	_toast.offset_right = 250
	_toast.offset_top = 80
	_toast.offset_bottom = 120
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.modulate.a = 0.0
	ui.add_child(_toast)


func _mk_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(handler)
	return b


func _build_params_panel(ui: CanvasLayer) -> void:
	_params_panel = PanelContainer.new()
	_params_panel.visible = false
	_params_panel.anchor_left = 0.5
	_params_panel.anchor_top = 0.5
	_params_panel.anchor_right = 0.5
	_params_panel.anchor_bottom = 0.5
	_params_panel.offset_left = -280
	_params_panel.offset_right = 280
	_params_panel.offset_top = -430
	_params_panel.offset_bottom = 430
	ui.add_child(_params_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_params_panel.add_child(box)

	var header := Label.new()
	header.text = "Параметры уровня"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 26)
	box.add_child(header)

	var name_row := HBoxContainer.new()
	box.add_child(name_row)
	var name_label := Label.new()
	name_label.text = "Название"
	name_label.custom_minimum_size = Vector2(180, 0)
	name_row.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.text = level_name
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(func(t: String): level_name = t)
	name_row.add_child(_name_edit)

	_add_spin(box, "Ширина (экранов)", 1, MAX_SCREENS_W, screens_w,
		func(v: float): _set_canvas_screens(int(v), screens_h))
	_add_spin(box, "Высота (экранов)", 1, MAX_SCREENS_H, screens_h,
		func(v: float): _set_canvas_screens(screens_w, int(v)))
	_add_spin(box, "Леммингов", 1, 100, total_lemmings, func(v: float): total_lemmings = int(v))
	_add_spin(box, "Спасти минимум", 1, 100, save_required, func(v: float): save_required = int(v))
	_add_spin(box, "Время (сек)", 30, 900, time_limit, func(v: float): time_limit = int(v))
	_add_spin(box, "Частота выхода", 1, 99, release_rate, func(v: float): release_rate = int(v))

	var skills_header := Label.new()
	skills_header.text = "Навыки"
	skills_header.add_theme_font_size_override("font_size", 22)
	box.add_child(skills_header)
	for k in SKILL_KEYS:
		var kk: String = k
		_add_spin(box, SKILL_LABELS[k], 0, 99, int(skill_counts[k]), func(v: float): skill_counts[kk] = int(v))

	box.add_child(_mk_button("Закрыть", _toggle_params))


func _add_spin(parent: Control, label_text: String, lo: int, hi: int, value: int, on_changed: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(180, 0)
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = lo
	spin.max_value = hi
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(on_changed)
	row.add_child(spin)
	_spins[label_text] = spin


func _toggle_params() -> void:
	_params_panel.visible = not _params_panel.visible
	if _params_panel.visible:
		_name_edit.text = level_name
		_spins["Ширина (экранов)"].value = screens_w
		_spins["Высота (экранов)"].value = screens_h
		_spins["Леммингов"].value = total_lemmings
		_spins["Спасти минимум"].value = save_required
		_spins["Время (сек)"].value = time_limit
		_spins["Частота выхода"].value = release_rate
		for k in SKILL_KEYS:
			_spins[SKILL_LABELS[k]].value = int(skill_counts[k])


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
