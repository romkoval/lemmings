## Terrain Builder — generates varied terrain from declarative specs.
class_name TerrainBuilder
extends RefCounted

const TERRAIN_LAYER: int = 0
const DIRT_SOURCE: int = 0
const GRASS_ATLAS := Vector2i(0, 0)
const DIRT_ATLAS := Vector2i(1, 0)
const MAX_TILE_Y: int = 40


static func build(tile_map: TileMap, data: Dictionary) -> void:
	for shape: Dictionary in data.get("terrain_rects", []):
		_build_rect(tile_map, shape)
	for shape: Dictionary in data.get("terrain_slopes", []):
		_build_slope(tile_map, shape)
	for shape: Dictionary in data.get("terrain_columns", []):
		_build_column(tile_map, shape)
	for shape: Dictionary in data.get("terrain_steps", []):
		_build_steps(tile_map, shape)
	for shape: Dictionary in data.get("terrain_pits", []):
		_build_pit(tile_map, shape)
	if data.get("add_depth", false):
		_add_depth(tile_map)


static func _build_rect(tile_map: TileMap, rect: Dictionary) -> void:
	var x0: int = int(rect.get("x", 0))
	var y0: int = int(rect.get("y", 0))
	var w: int = int(rect.get("w", 1))
	var h: int = int(rect.get("h", 1))
	var no_grass: bool = bool(rect.get("no_grass", false))
	for dy: int in h:
		var atlas: Vector2i = DIRT_ATLAS
		if dy == 0 and not no_grass:
			atlas = GRASS_ATLAS
		for dx: int in w:
			tile_map.set_cell(TERRAIN_LAYER, Vector2i(x0 + dx, y0 + dy), DIRT_SOURCE, atlas)


static func _build_slope(tile_map: TileMap, shape: Dictionary) -> void:
	var x0: int = int(shape.get("x", 0))
	var y0: int = int(shape.get("y", 0))
	var w: int = int(shape.get("w", 4))
	var h: int = int(shape.get("h", 4))
	var dir: String = str(shape.get("direction", "up_right"))
	for dy: int in h:
		for dx: int in w:
			var fill: bool = false
			match dir:
				"up_right":
					fill = dy >= h - 1 - int(float(dx) / float(w) * float(h))
				"up_left":
					fill = dy >= int(float(dx) / float(w) * float(h))
				"down_right":
					fill = dy <= int(float(dx) / float(w) * float(h))
				"down_left":
					fill = dy <= h - 1 - int(float(dx) / float(w) * float(h))
			if fill:
				var atlas: Vector2i = DIRT_ATLAS
				var is_surface: bool = false
				match dir:
					"up_right":
						is_surface = (dy == h - 1 - int(float(dx) / float(w) * float(h)))
					"up_left":
						is_surface = (dy == int(float(dx) / float(w) * float(h)))
					"down_right":
						is_surface = (dy == int(float(dx) / float(w) * float(h)))
					"down_left":
						is_surface = (dy == h - 1 - int(float(dx) / float(w) * float(h)))
				if is_surface:
					atlas = GRASS_ATLAS
				tile_map.set_cell(TERRAIN_LAYER, Vector2i(x0 + dx, y0 + dy), DIRT_SOURCE, atlas)


static func _build_column(tile_map: TileMap, shape: Dictionary) -> void:
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


static func _build_steps(tile_map: TileMap, shape: Dictionary) -> void:
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


static func _build_pit(tile_map: TileMap, shape: Dictionary) -> void:
	var x0: int = int(shape.get("x", 0))
	var y0: int = int(shape.get("y", 0))
	var w: int = int(shape.get("w", 2))
	var h: int = int(shape.get("h", 2))
	for dy: int in h:
		for dx: int in w:
			tile_map.erase_cell(TERRAIN_LAYER, Vector2i(x0 + dx, y0 + dy))


static func _add_depth(tile_map: TileMap) -> void:
	var all_cells: Array[Vector2i] = tile_map.get_used_cells(TERRAIN_LAYER)
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
