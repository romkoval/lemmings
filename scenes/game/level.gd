class_name Level
extends Node2D

const TILE_SIZE: int = 16
# TileSet source ids: terrain tiles live on source 0, steel on source 1. Since
# the 4.6 migration each occupies its own TileMapLayer node (terrain_layer /
# steel_layer) instead of two layers of a single deprecated TileMap.
const DIRT_SOURCE: int = 0
const STEEL_SOURCE: int = 1

@export var level_id: String = ""
@export var save_required: int = 1
@export var time_limit: int = 300
@export var total_lemmings: int = 10
@export var release_rate: int = 50
@export var skill_counts: Dictionary = {
	"climber": 0,
	"floater": 0,
	"bomber": 0,
	"blocker": 0,
	"builder": 0,
	"basher": 0,
	"miner": 0,
	"digger": 10,
}

@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var steel_layer: TileMapLayer = $SteelLayer
@onready var entrance: Entrance = $Entrance
@onready var level_exit: LevelExit = $LevelExit


func _ready() -> void:
	if entrance:
		entrance.configure(total_lemmings, release_rate)


func is_steel_at(tile_coord: Vector2i) -> bool:
	return steel_layer != null and steel_layer.get_cell_source_id(tile_coord) != -1


func is_terrain_at(tile_coord: Vector2i) -> bool:
	return terrain_layer != null and terrain_layer.get_cell_source_id(tile_coord) != -1


func is_solid_at(tile_coord: Vector2i) -> bool:
	return is_terrain_at(tile_coord) or is_steel_at(tile_coord)


func remove_terrain_at(tile_coord: Vector2i) -> bool:
	if terrain_layer == null:
		return false
	if is_steel_at(tile_coord):
		return false
	if terrain_layer.get_cell_source_id(tile_coord) == -1:
		return false
	terrain_layer.erase_cell(tile_coord)
	return true


func add_terrain_at(tile_coord: Vector2i, source_id: int = DIRT_SOURCE, atlas: Vector2i = Vector2i.ZERO) -> bool:
	if terrain_layer == null:
		return false
	if terrain_layer.get_cell_source_id(tile_coord) != -1:
		return false
	terrain_layer.set_cell(tile_coord, source_id, atlas)
	return true


func world_to_tile(world_pos: Vector2) -> Vector2i:
	# floori (not int truncation) so negative world coordinates map correctly:
	# a lemming at x=-1 belongs to tile -1, not tile 0.
	return Vector2i(floori(world_pos.x / TILE_SIZE), floori(world_pos.y / TILE_SIZE))


func tile_to_world(tile_coord: Vector2i) -> Vector2:
	return Vector2(tile_coord.x * TILE_SIZE, tile_coord.y * TILE_SIZE)
