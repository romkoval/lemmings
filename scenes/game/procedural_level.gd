class_name ProceduralLevel
extends Level

@export var data_path: String = ""

const BG_TEX_PATH := "res://assets/sprites/bg_sky.png"
const DIRT_SOURCE: int = 0
const GRASS_ATLAS := Vector2i(0, 0)
const DIRT_ATLAS := Vector2i(1, 0)
const RAMP_R_ATLAS := Vector2i(0, 1)   # 45° slope rising to the right
const RAMP_L_ATLAS := Vector2i(1, 1)   # 45° slope rising to the left
const MAX_TILE_Y: int = 40


func _ready() -> void:
	_ensure_background()
	if data_path != "" and FileAccess.file_exists(data_path):
		_apply_data(_read_json(data_path))
	_build_default_floor_if_empty()
	super._ready()


func _ensure_background() -> void:
	if has_node("Background"):
		return
	var layer := CanvasLayer.new()
	layer.name = "Background"
	layer.layer = -10
	add_child(layer)
	var floor_rect := ColorRect.new()
	floor_rect.anchor_right = 1.0
	floor_rect.anchor_bottom = 1.0
	floor_rect.color = Color(0.024, 0.020, 0.094)
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(floor_rect)
	if ResourceLoader.exists(BG_TEX_PATH):
		var tex: Texture2D = load(BG_TEX_PATH) as Texture2D
		if tex:
			var rect := TextureRect.new()
			rect.texture = tex
			rect.anchor_right = 1.0
			rect.anchor_bottom = 1.0
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(rect)


func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var t: String = f.get_as_text()
	f.close()
	var j := JSON.new()
	if j.parse(t) != OK:
		return {}
	return j.data


func _apply_data(d: Dictionary) -> void:
	if d.is_empty():
		return
	level_id = d.get("id", level_id)
	save_required = int(d.get("save_required", save_required))
	time_limit = int(d.get("time_limit", time_limit))
	total_lemmings = int(d.get("total_lemmings", total_lemmings))
	release_rate = int(d.get("release_rate", release_rate))
	var sk = d.get("skill_counts", null)
	if sk is Dictionary:
		skill_counts = sk
	if entrance:
		var ep = d.get("entrance_pos", null)
		if ep is Array and ep.size() == 2:
			entrance.position = Vector2(ep[0], ep[1])
		entrance.initial_direction = int(d.get("entrance_direction", 1))
	if level_exit:
		var xp = d.get("exit_pos", null)
		if xp is Array and xp.size() == 2:
			level_exit.position = Vector2(xp[0], xp[1])

	# --- Terrain building ---
	for shape: Dictionary in d.get("terrain_rects", []):
		_build_terrain_rect(shape)
	for shape: Dictionary in d.get("terrain_slopes", []):
		_build_terrain_slope(shape)
	for shape: Dictionary in d.get("terrain_columns", []):
		_build_terrain_column(shape)
	for shape: Dictionary in d.get("terrain_steps", []):
		_build_terrain_steps(shape)
	for shape: Dictionary in d.get("terrain_pits", []):
		_build_terrain_pit(shape)
	if d.get("add_depth", false):
		_add_depth()

	for cell in d.get("steel", []):
		if cell is Array and cell.size() == 2:
			var c2 := Vector2i(int(cell[0]), int(cell[1]))
			tile_map.set_cell(STEEL_LAYER, c2, 1, _steel_variant(c2.x, c2.y))
	for rect_dict in d.get("steel_rects", []):
		_fill_steel_rect(rect_dict)


# ── Terrain shapes ─────────────────────────────────────────────────────

func _build_terrain_rect(rect: Dictionary) -> void:
	var x0: int = int(rect.get("x", 0))
	var y0: int = int(rect.get("y", 0))
	var w: int = int(rect.get("w", 1))
	var h: int = int(rect.get("h", 1))
	var no_grass: bool = bool(rect.get("no_grass", false))
	# Optional surface undulation (tiles): the top of the rect rolls in smooth
	# hills built from 45° ramp tiles, so lemmings walk genuine slopes instead of
	# square steps. It only ADDS tiles above y0 — the solid body from y0 down is
	# never touched, so puzzle geometry and solvability are preserved.
	var amp: int = int(rect.get("undulate", 0))
	# Surface heights sampled at every column boundary (w+1 posts). Two low-freq
	# sines give rolling hills across the full 0..amp range; flat pads under the
	# hatch and exit keep spawning/exiting aligned, with the hills ramping down to
	# them. Adjacent posts differ by at most one tile, so each column is either a
	# flat top or a single ramp.
	var pad_cols: Array[int] = []
	if amp > 0:
		if entrance:
			pad_cols.append(world_to_tile(entrance.position).x)
		if level_exit:
			pad_cols.append(world_to_tile(level_exit.position).x)
	var ramp_dist: float = float(amp * 2 + 1)
	var heights: Array[int] = []
	for i: int in range(w + 1):
		var tx: int = x0 + i
		var hh: int = 0
		if amp > 0:
			var hf: float = 0.5 + 0.34 * sin(tx * 0.5) + 0.16 * sin(tx * 0.23 + 1.3)
			var mask: float = 1.0
			for pc: int in pad_cols:
				mask = minf(mask, clampf(abs(tx - pc) / ramp_dist, 0.0, 1.0))
			hh = clampi(int(round(amp * hf * mask)), 0, amp)
		heights.append(hh)

	for dx: int in w:
		var tx: int = x0 + dx
		var lh: int = heights[dx]       # surface height at this column's left edge
		var rh: int = heights[dx + 1]   # ...and its right edge
		var top_row: int
		var top_atlas: Vector2i
		if rh > lh:                     # rising to the right → ramp up
			top_row = y0 - rh
			top_atlas = RAMP_R_ATLAS
		elif rh < lh:                   # falling to the right → ramp down
			top_row = y0 - lh
			top_atlas = RAMP_L_ATLAS
		else:                           # level → flat grass (or bare dirt)
			top_row = y0 - lh
			top_atlas = _dirt_variant(tx, top_row) if no_grass else _grass_variant(tx, top_row)
		tile_map.set_cell(TERRAIN_LAYER, Vector2i(tx, top_row), DIRT_SOURCE, top_atlas)
		for ty in range(top_row + 1, y0 + h):
			tile_map.set_cell(TERRAIN_LAYER, Vector2i(tx, ty), DIRT_SOURCE, _dirt_variant(tx, ty))


func _build_terrain_slope(shape: Dictionary) -> void:
	var x0: int = int(shape.get("x", 0))
	var y0: int = int(shape.get("y", 0))
	var w: int = int(shape.get("w", 4))
	var h: int = int(shape.get("h", 4))
	var dir: String = str(shape.get("direction", "up_right"))
	for dy: int in h:
		for dx: int in w:
			var fill: bool = false
			var threshold: int
			match dir:
				"up_right":
					threshold = h - 1 - int(float(dx) / float(w) * float(h))
					fill = dy >= threshold
				"up_left":
					threshold = int(float(dx) / float(w) * float(h))
					fill = dy >= threshold
				"down_right":
					threshold = int(float(dx) / float(w) * float(h))
					fill = dy <= threshold
				"down_left":
					threshold = h - 1 - int(float(dx) / float(w) * float(h))
					fill = dy <= threshold
			if fill:
				var is_surface: bool = (dy == threshold)
				var atlas: Vector2i = DIRT_ATLAS
				if is_surface:
					atlas = GRASS_ATLAS
				tile_map.set_cell(TERRAIN_LAYER, Vector2i(x0 + dx, y0 + dy), DIRT_SOURCE, atlas)


func _build_terrain_column(shape: Dictionary) -> void:
	var x0: int = int(shape.get("x", 0))
	var y0: int = int(shape.get("y", 0))
	var w: int = int(shape.get("w", 2))
	var h: int = int(shape.get("h", 3))
	var has_grass: bool = not bool(shape.get("no_grass", false))
	for dy: int in h:
		for dx: int in w:
			var atlas: Vector2i = DIRT_ATLAS
			if dy == 0 and has_grass:
				atlas = GRASS_ATLAS
			tile_map.set_cell(TERRAIN_LAYER, Vector2i(x0 + dx, y0 + dy), DIRT_SOURCE, atlas)
	if has_grass:
		var shadow_y: int = y0 + h
		for dx: int in w:
			for sd: int in range(1, 3):
				var sy: int = shadow_y + sd
				if sy < MAX_TILE_Y:
					var existing: int = tile_map.get_cell_source_id(TERRAIN_LAYER, Vector2i(x0 + dx, sy))
					if existing == -1:
						tile_map.set_cell(TERRAIN_LAYER, Vector2i(x0 + dx, sy), DIRT_SOURCE, DIRT_ATLAS)


func _build_terrain_steps(shape: Dictionary) -> void:
	var x0: int = int(shape.get("x", 0))
	var y0: int = int(shape.get("y", 0))
	var step_w: int = int(shape.get("step_w", 2))
	var step_h: int = int(shape.get("step_h", 1))
	var num_steps: int = int(shape.get("num_steps", 4))
	var direction: String = str(shape.get("direction", "right"))
	for i: int in num_steps:
		var sx: int = x0 + i * step_w if direction == "right" else x0 - i * step_w
		var sy: int = y0 - i * step_h
		var fill_h: int = (num_steps - i) * step_h + 2
		for dy: int in fill_h:
			for dx: int in step_w:
				var atlas: Vector2i = DIRT_ATLAS
				if dy == 0:
					atlas = GRASS_ATLAS
				tile_map.set_cell(TERRAIN_LAYER, Vector2i(sx + dx, sy + dy), DIRT_SOURCE, atlas)


func _build_terrain_pit(shape: Dictionary) -> void:
	var x0: int = int(shape.get("x", 0))
	var y0: int = int(shape.get("y", 0))
	var w: int = int(shape.get("w", 2))
	var h: int = int(shape.get("h", 2))
	for dy: int in h:
		for dx: int in w:
			tile_map.erase_cell(TERRAIN_LAYER, Vector2i(x0 + dx, y0 + dy))


func _add_depth() -> void:
	var all_cells: Array[Vector2i]
	all_cells.assign(tile_map.get_used_cells(TERRAIN_LAYER))
	var cell_set: Dictionary = {}
	for c: Vector2i in all_cells:
		cell_set[c] = true

	for cell: Vector2i in all_cells:
		var below: Vector2i = Vector2i(cell.x, cell.y + 1)
		if not cell_set.has(below):
			for d: int in range(1, 4):
				var depth_cell: Vector2i = Vector2i(cell.x, cell.y + d)
				if not cell_set.has(depth_cell) and depth_cell.y < MAX_TILE_Y:
					tile_map.set_cell(TERRAIN_LAYER, depth_cell, DIRT_SOURCE, DIRT_ATLAS)
					cell_set[depth_cell] = true


# ── Steel ──────────────────────────────────────────────────────────────

func _fill_steel_rect(rect: Dictionary) -> void:
	var x0: int = int(rect.get("x", 0))
	var y0: int = int(rect.get("y", 0))
	var w: int = int(rect.get("w", 1))
	var h: int = int(rect.get("h", 1))
	for dy in h:
		for dx in w:
			var tx: int = x0 + dx
			var ty: int = y0 + dy
			tile_map.set_cell(STEEL_LAYER, Vector2i(tx, ty), 1, _steel_variant(tx, ty))


# ── Variant pickers ────────────────────────────────────────────────────

func _grass_variant(x: int, y: int) -> Vector2i:
	var h: int = wrapi(x * 73 + y * 31, 0, 100)
	return Vector2i(2, 0) if h < 25 else Vector2i(0, 0)


func _dirt_variant(x: int, y: int) -> Vector2i:
	var h: int = wrapi(x * 53 + y * 97, 0, 100)
	if h < 10:
		return Vector2i(4, 0)
	if h < 40:
		return Vector2i(3, 0)
	return Vector2i(1, 0)


func _steel_variant(x: int, y: int) -> Vector2i:
	var h: int = wrapi(x * 41 + y * 67, 0, 100)
	if h < 12:
		return Vector2i(2, 0)
	if h < 50:
		return Vector2i(1, 0)
	return Vector2i(0, 0)


func _build_default_floor_if_empty() -> void:
	if tile_map == null:
		return
	var has_any: bool = false
	for cell in tile_map.get_used_cells(TERRAIN_LAYER):
		has_any = true
		break
	if has_any:
		return
	for x in range(0, 45):
		tile_map.set_cell(TERRAIN_LAYER, Vector2i(x, 30), 0, _grass_variant(x, 30))
	for x in range(0, 45):
		tile_map.set_cell(TERRAIN_LAYER, Vector2i(x, 31), 0, _dirt_variant(x, 31))
