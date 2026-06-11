class_name LevelEditor
extends Node2D

# In-game level editor (touch-first). The player paints terrain on the 16px
# AUTHORING grid — the same tile format campaign levels use — places the
# entrance/exit, sets level parameters and saves to user://custom_levels/*.json.
# Played levels go through the normal pipeline (ProceduralLevel rasterizes the
# tiles into the per-pixel terrain), so custom levels behave exactly like
# campaign ones.
#
# Input: one finger / LMB paints with the active tool; two fingers pinch-zoom
# and pan; mouse wheel zooms, right/middle drag pans.

const CANVAS_TILES := Vector2i(45, 80)          # 720×1280 world px
const TILE: int = 16
const DIRT_ATLAS := Vector2i(1, 0)
const RAMP_R_ATLAS := Vector2i(0, 1)
const RAMP_L_ATLAS := Vector2i(1, 1)

enum Tool { DIRT, RAMP_R, RAMP_L, STEEL, ERASE, ENTRANCE, EXIT }

const TOOL_LABELS: Dictionary = {
	Tool.DIRT: "Грунт",
	Tool.RAMP_R: "Склон ◢",
	Tool.RAMP_L: "Склон ◣",
	Tool.STEEL: "Сталь",
	Tool.ERASE: "Ластик",
	Tool.ENTRANCE: "Вход",
	Tool.EXIT: "Выход",
}

const SKILL_KEYS: Array = [
	"climber", "floater", "bomber", "blocker", "builder", "basher", "miner", "digger"]
const SKILL_LABELS: Dictionary = {
	"climber": "Альпинист", "floater": "Парашютист", "bomber": "Бомбер",
	"blocker": "Блокер", "builder": "Строитель", "basher": "Долбильщик",
	"miner": "Шахтёр", "digger": "Копатель",
}

@onready var terrain_layer: TileMapLayer = $World/TerrainLayer
@onready var steel_layer: TileMapLayer = $World/SteelLayer
@onready var entrance: Node2D = $World/Entrance
@onready var level_exit: Node2D = $World/LevelExit
@onready var camera: Camera2D = $Camera2D

var tool: Tool = Tool.DIRT
var level_name: String = "Мой уровень"
var level_id: String = ""
var save_path: String = ""
var total_lemmings: int = 10
var save_required: int = 5
var time_limit: int = 300
var release_rate: int = 50
var skill_counts: Dictionary = {}

var _painting: bool = false
var _last_cell: Vector2i = Vector2i(-1000, -1000)
var _touches: Dictionary = {}
var _gesture: bool = false
var _pinch_start_dist: float = 0.0
var _pinch_start_zoom: float = 1.0
var _pan_last: Vector2 = Vector2.ZERO
var _mouse_panning: bool = false

var _tool_buttons: Dictionary = {}
var _params_panel: PanelContainer = null
var _name_edit: LineEdit = null
var _spins: Dictionary = {}
var _toast: Label = null


func _ready() -> void:
	GameManager.set_state(GameManager.GameState.MENU)
	for k in SKILL_KEYS:
		skill_counts[k] = 2
	_build_ui()
	camera.setup_bounds(self, Vector2(360.0, 640.0))
	camera.set_zoom_level(1.0)
	# Returning from a test run (or opening an existing level from the browser).
	if LevelManager.editing_path != "":
		_load_from(LevelManager.editing_path)
	queue_redraw()


# camera_controller asks the bound node for pan bounds — the editor's canvas.
func get_terrain_bounds_px() -> Rect2:
	return Rect2(0, 0, CANVAS_TILES.x * TILE, CANVAS_TILES.y * TILE)


# ── Canvas grid ──────────────────────────────────────────────────────────────

func _draw() -> void:
	var w: float = float(CANVAS_TILES.x * TILE)
	var h: float = float(CANVAS_TILES.y * TILE)
	var faint := Color(1, 1, 1, 0.07)
	for x in range(CANVAS_TILES.x + 1):
		draw_line(Vector2(x * TILE, 0), Vector2(x * TILE, h), faint)
	for y in range(CANVAS_TILES.y + 1):
		draw_line(Vector2(0, y * TILE), Vector2(w, y * TILE), faint)
	draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.35), false, 2.0)


# ── Painting ─────────────────────────────────────────────────────────────────

func _cell_at(world: Vector2) -> Vector2i:
	return Vector2i(floori(world.x / TILE), floori(world.y / TILE))


func _in_canvas(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < CANVAS_TILES.x and c.y < CANVAS_TILES.y


func _apply_tool(world: Vector2) -> void:
	var c: Vector2i = _cell_at(world)
	if not _in_canvas(c):
		return
	if c == _last_cell and tool != Tool.ENTRANCE and tool != Tool.EXIT:
		return
	_last_cell = c
	match tool:
		Tool.DIRT:
			steel_layer.erase_cell(c)
			terrain_layer.set_cell(c, Level.DIRT_SOURCE, DIRT_ATLAS)
		Tool.RAMP_R:
			steel_layer.erase_cell(c)
			terrain_layer.set_cell(c, Level.DIRT_SOURCE, RAMP_R_ATLAS)
		Tool.RAMP_L:
			steel_layer.erase_cell(c)
			terrain_layer.set_cell(c, Level.DIRT_SOURCE, RAMP_L_ATLAS)
		Tool.STEEL:
			terrain_layer.erase_cell(c)
			steel_layer.set_cell(c, Level.STEEL_SOURCE, Vector2i.ZERO)
		Tool.ERASE:
			terrain_layer.erase_cell(c)
			steel_layer.erase_cell(c)
		Tool.ENTRANCE:
			entrance.position = Vector2(c.x * TILE + 8, c.y * TILE + 8)
		Tool.EXIT:
			level_exit.position = Vector2(c.x * TILE + 8, c.y * TILE + 8)


# ── Input: paint / pan / zoom ────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
			if _touches.size() == 1:
				_painting = true
				_last_cell = Vector2i(-1000, -1000)
				_apply_tool(_screen_to_world(st.position))
			else:
				_painting = false
				_gesture = true
				_start_pinch()
		else:
			_touches.erase(st.index)
			if _touches.is_empty():
				_painting = false
				_gesture = false
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _gesture and _touches.size() >= 2:
			_update_pinch()
		elif _painting:
			_apply_tool(_screen_to_world(sd.position))
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_painting = mb.pressed
			if mb.pressed:
				_last_cell = Vector2i(-1000, -1000)
				_apply_tool(get_global_mouse_position())
		elif mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_mouse_panning = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			camera.zoom_by(1.1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			camera.zoom_by(1.0 / 1.1)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _mouse_panning:
			camera.pan_screen(mm.relative)
		elif _painting:
			_apply_tool(get_global_mouse_position())


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

func _collect_data() -> Dictionary:
	if level_id == "":
		level_id = "custom_%d" % (Time.get_unix_time_from_system() as int)
	var tiles: Array = []
	for c in terrain_layer.get_used_cells():
		var atlas: Vector2i = terrain_layer.get_cell_atlas_coords(c)
		tiles.append([c.x, c.y, atlas.x, atlas.y])
	var steel: Array = []
	for c in steel_layer.get_used_cells():
		steel.append([c.x, c.y])
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
		"terrain_tiles": tiles,
		"steel": steel,
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
	terrain_layer.clear()
	steel_layer.clear()
	for cell in d.get("terrain_tiles", []):
		if cell is Array and cell.size() >= 2:
			var atlas := DIRT_ATLAS
			if cell.size() >= 4:
				atlas = Vector2i(int(cell[2]), int(cell[3]))
			terrain_layer.set_cell(Vector2i(int(cell[0]), int(cell[1])), Level.DIRT_SOURCE, atlas)
	for cell in d.get("steel", []):
		if cell is Array and cell.size() == 2:
			steel_layer.set_cell(Vector2i(int(cell[0]), int(cell[1])), Level.STEEL_SOURCE, Vector2i.ZERO)


func _save(show_toast: bool = true) -> bool:
	if terrain_layer.get_used_cells().is_empty():
		_show_toast("Нарисуйте ландшафт перед сохранением")
		return false
	if save_path == "":
		_collect_data()   # assigns level_id
		save_path = LevelManager.CUSTOM_LEVELS_DIR + level_id + ".json"
	var ok: bool = LevelManager.save_level_json(save_path, _collect_data())
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

	# Bottom tool bar.
	var bottom := PanelContainer.new()
	bottom.anchor_top = 1.0
	bottom.anchor_right = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -84
	ui.add_child(bottom)
	var tool_box := HBoxContainer.new()
	tool_box.alignment = BoxContainer.ALIGNMENT_CENTER
	tool_box.add_theme_constant_override("separation", 6)
	bottom.add_child(tool_box)
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
		_tool_buttons[t] = b

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
