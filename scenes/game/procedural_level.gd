class_name ProceduralLevel
extends Level

@export var data_path: String = ""

# Background canvas is created lazily on _ready so any level scene that
# extends ProceduralLevel automatically gets the sky behind its TileMap,
# including when loaded standalone by the screenshot tool (which doesn't
# go through scenes/game/game.tscn).
const BG_TEX_PATH := "res://assets/sprites/bg_sky.png"


func _ready() -> void:
	_ensure_background()
	if data_path != "" and FileAccess.file_exists(data_path):
		_apply_data(_read_json(data_path))
	_build_default_floor_if_empty()
	super._ready()


func _ensure_background() -> void:
	# If the scene already declares a Background node we trust the author.
	if has_node("Background"):
		return
	var layer := CanvasLayer.new()
	layer.name = "Background"
	layer.layer = -10
	add_child(layer)
	# Solid clear color so any sliver around the tiling texture still reads
	# as sky, not the engine's pitch-black clear.
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

	var terrain: Array = d.get("terrain", [])
	for cell in terrain:
		if cell is Array and cell.size() == 2:
			var c := Vector2i(int(cell[0]), int(cell[1]))
			tile_map.set_cell(TERRAIN_LAYER, c, 0, _dirt_variant(c.x, c.y))
	var steel: Array = d.get("steel", [])
	for cell in steel:
		if cell is Array and cell.size() == 2:
			var c2 := Vector2i(int(cell[0]), int(cell[1]))
			tile_map.set_cell(STEEL_LAYER, c2, 1, _steel_variant(c2.x, c2.y))
	for rect_dict in d.get("terrain_rects", []):
		_fill_terrain_rect(rect_dict)
	for rect_dict in d.get("steel_rects", []):
		_fill_steel_rect(rect_dict)


# Top row gets a grass-topped atlas tile; deeper rows use dirt body variants.
# Variants are picked deterministically from (x, y) so the same level always
# looks the same but adjacent tiles differ enough to break the grid feel.
func _fill_terrain_rect(rect: Dictionary) -> void:
	var x0: int = int(rect.get("x", 0))
	var y0: int = int(rect.get("y", 0))
	var w: int = int(rect.get("w", 1))
	var h: int = int(rect.get("h", 1))
	for dy in h:
		var tile_y: int = y0 + dy
		for dx in w:
			var tile_x: int = x0 + dx
			var atlas: Vector2i
			if dy == 0:
				atlas = _grass_variant(tile_x, tile_y)
			else:
				atlas = _dirt_variant(tile_x, tile_y)
			tile_map.set_cell(TERRAIN_LAYER, Vector2i(tile_x, tile_y), 0, atlas)


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


# Grass top: cols 0 and 2 in the atlas. Variant B (flowers) is rarer (~25%).
func _grass_variant(x: int, y: int) -> Vector2i:
	var h := wrapi(x * 73 + y * 31, 0, 100)
	return Vector2i(2, 0) if h < 25 else Vector2i(0, 0)


# Dirt body: cols 1 (A — pebbles), 3 (B — roots), 4 (C — stone). C is the
# rarest because it has a chunky stone that looks weird if it tiles densely.
func _dirt_variant(x: int, y: int) -> Vector2i:
	var h := wrapi(x * 53 + y * 97, 0, 100)
	if h < 10:
		return Vector2i(4, 0)
	if h < 40:
		return Vector2i(3, 0)
	return Vector2i(1, 0)


# Steel: cols 0 (plate), 1 (rivet), 2 (warning). Warning stripes are rare so
# they read as accent tiles, not the whole wall.
func _steel_variant(x: int, y: int) -> Vector2i:
	var h := wrapi(x * 41 + y * 67, 0, 100)
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
