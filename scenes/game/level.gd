class_name Level
extends Node2D

const TILE_SIZE: int = 16
const TERRAIN_LAYER: int = 0
const STEEL_LAYER: int = 1

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

@onready var tile_map: TileMap = $TileMap
@onready var entrance: Entrance = $Entrance
@onready var level_exit: LevelExit = $LevelExit


func _ready() -> void:
	if entrance:
		entrance.configure(total_lemmings, release_rate)


func is_steel_at(tile_coord: Vector2i) -> bool:
	if tile_map == null:
		return false
	return tile_map.get_cell_source_id(STEEL_LAYER, tile_coord) != -1


func remove_terrain_at(tile_coord: Vector2i) -> bool:
	if tile_map == null:
		return false
	if is_steel_at(tile_coord):
		return false
	if tile_map.get_cell_source_id(TERRAIN_LAYER, tile_coord) == -1:
		return false
	tile_map.set_cell(TERRAIN_LAYER, tile_coord, -1)
	return true


func add_terrain_at(tile_coord: Vector2i, source_id: int = 0, atlas: Vector2i = Vector2i.ZERO) -> bool:
	if tile_map == null:
		return false
	if tile_map.get_cell_source_id(TERRAIN_LAYER, tile_coord) != -1:
		return false
	tile_map.set_cell(TERRAIN_LAYER, tile_coord, source_id, atlas)
	return true


func world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x) / TILE_SIZE, int(world_pos.y) / TILE_SIZE)


func tile_to_world(tile_coord: Vector2i) -> Vector2:
	return Vector2(tile_coord.x * TILE_SIZE, tile_coord.y * TILE_SIZE)
