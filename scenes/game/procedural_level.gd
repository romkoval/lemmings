class_name ProceduralLevel
extends Level

@export var data_path: String = ""


func _ready() -> void:
	if data_path != "" and FileAccess.file_exists(data_path):
		_apply_data(_read_json(data_path))
	_build_default_floor_if_empty()
	super._ready()


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
			tile_map.set_cell(TERRAIN_LAYER, Vector2i(int(cell[0]), int(cell[1])), 0, Vector2i.ZERO)
	var steel: Array = d.get("steel", [])
	for cell in steel:
		if cell is Array and cell.size() == 2:
			tile_map.set_cell(STEEL_LAYER, Vector2i(int(cell[0]), int(cell[1])), 1, Vector2i.ZERO)
	for rect_dict in d.get("terrain_rects", []):
		_fill_terrain_rect(rect_dict)
	for rect_dict in d.get("steel_rects", []):
		_fill_rect(rect_dict, STEEL_LAYER, 1, Vector2i.ZERO)


func _fill_rect(rect: Dictionary, layer: int, source_id: int, atlas: Vector2i) -> void:
	var x0: int = int(rect.get("x", 0))
	var y0: int = int(rect.get("y", 0))
	var w: int = int(rect.get("w", 1))
	var h: int = int(rect.get("h", 1))
	for dy in h:
		for dx in w:
			tile_map.set_cell(layer, Vector2i(x0 + dx, y0 + dy), source_id, atlas)


# Top row gets the grass-topped atlas tile; rows below use the plain-dirt tile.
func _fill_terrain_rect(rect: Dictionary) -> void:
	var x0: int = int(rect.get("x", 0))
	var y0: int = int(rect.get("y", 0))
	var w: int = int(rect.get("w", 1))
	var h: int = int(rect.get("h", 1))
	for dy in h:
		var atlas: Vector2i = Vector2i.ZERO if dy == 0 else Vector2i(1, 0)
		for dx in w:
			tile_map.set_cell(TERRAIN_LAYER, Vector2i(x0 + dx, y0 + dy), 0, atlas)


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
		tile_map.set_cell(TERRAIN_LAYER, Vector2i(x, 30), 0, Vector2i.ZERO)
	for x in range(0, 45):
		tile_map.set_cell(TERRAIN_LAYER, Vector2i(x, 31), 0, Vector2i(1, 0))
