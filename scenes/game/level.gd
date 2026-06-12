class_name Level
extends Node2D

const TILE_SIZE: int = 16
# TileSet source ids — used only while AUTHORING (procedural generation /
# editor-placed cells). At runtime the tile layers are rasterized into the
# per-pixel terrain and hidden; gameplay never touches tiles again.
const DIRT_SOURCE: int = 0
const STEEL_SOURCE: int = 1

@export var level_id: String = ""
@export var save_required: int = 1
@export var time_limit: int = 300
@export var total_lemmings: int = 10
@export var release_rate: int = 50
@export var terrain_theme: String = "dirt"   # visual palette: dirt/fire/marble/crystal
@export var hint: String = ""                # onboarding tip shown once (US-5.2)
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

var pixel_terrain: PixelTerrain = null
# Editor-made levels carry their terrain as painted images instead of tiles;
# ProceduralLevel fills these from the level JSON before super._ready() runs.
var pending_terrain_mask: Image = null
var pending_terrain_mat: Image = null
var pending_terrain_origin: Vector2i = Vector2i.ZERO


func _ready() -> void:
	if entrance:
		entrance.configure(total_lemmings, release_rate)
	_build_pixel_terrain()


# Build the per-pixel terrain: either straight from painted images (level
# editor format, no smoothing — WYSIWYG) or by rasterizing the authored tile
# layers. The tiles are then retired: hidden and physics off — from here on
# the pixel mask is the only truth for both collision and rendering.
func _build_pixel_terrain() -> void:
	pixel_terrain = PixelTerrain.new()
	pixel_terrain.name = "PixelTerrain"
	pixel_terrain.theme_name = terrain_theme
	add_child(pixel_terrain)
	move_child(pixel_terrain, mini(2, get_child_count() - 1))
	if pending_terrain_mask != null:
		pixel_terrain.build_from_images(pending_terrain_mask, pending_terrain_mat, pending_terrain_origin)
		pending_terrain_mask = null
		pending_terrain_mat = null
	else:
		pixel_terrain.build_from_tiles(terrain_layer, steel_layer)
	terrain_layer.visible = false
	terrain_layer.collision_enabled = false
	steel_layer.visible = false
	steel_layer.collision_enabled = false


# ── Pixel terrain API (world pixel coordinates) ─────────────────────────────

func is_solid_px(wp: Vector2) -> bool:
	return pixel_terrain != null and pixel_terrain.is_solid_px(wp)


func is_steel_px(wp: Vector2) -> bool:
	return pixel_terrain != null and pixel_terrain.is_steel_px(wp)


# Carve destructible pixels (steel survives; dir = ±1 also respects one-way
# walls, dir = 0 ignores them). Returns pixels removed.
func carve_rect_px(r: Rect2i, dir: int = 0) -> int:
	return pixel_terrain.carve_rect(r, dir) if pixel_terrain != null else 0


# Would a directional carve hit steel or an opposing one-way wall?
func rect_blocks_carve_px(r: Rect2i, dir: int) -> bool:
	return pixel_terrain != null and pixel_terrain.rect_blocks_carve(r, dir)


func oneway_dir_px(wp: Vector2) -> int:
	return pixel_terrain.oneway_dir_px(wp) if pixel_terrain != null else 0


func carve_circle_px(center: Vector2, radius: float) -> int:
	return pixel_terrain.carve_circle(center, radius) if pixel_terrain != null else 0


func fill_rect_px(r: Rect2i, mat: float = PixelTerrain.MAT_DIRT) -> void:
	if pixel_terrain != null:
		pixel_terrain.fill_rect(r, mat)


func rect_has_steel_px(r: Rect2i) -> bool:
	return pixel_terrain != null and pixel_terrain.rect_has_steel(r)


# ── Authoring helpers ───────────────────────────────────────────────────────

# The authored playfield in world pixels (editor levels save it explicitly;
# ProceduralLevel fills it from the level JSON). Empty = derive from tiles.
var playfield_rect: Rect2 = Rect2()


# Bounding box the camera may pan over. Starts from the explicit playfield (or
# the authored tile rect), then always includes one screen at the origin plus
# the entrance and exit — so spawn and goal can never sit outside the
# scrollable area no matter how the level was authored.
func get_terrain_bounds_px() -> Rect2:
	var base: Rect2 = playfield_rect
	if not base.has_area():
		var r: Rect2i = Rect2i()
		if terrain_layer != null:
			r = terrain_layer.get_used_rect()
		if steel_layer != null:
			var rs: Rect2i = steel_layer.get_used_rect()
			if rs.has_area():
				r = rs if not r.has_area() else r.merge(rs)
		if r.has_area():
			base = Rect2(Vector2(r.position * TILE_SIZE), Vector2(r.size * TILE_SIZE))
	if not base.has_area():
		base = Rect2(0, 0, 720, 1280)
	else:
		base = base.merge(Rect2(0, 0, 720, 1280))
	if entrance != null:
		base = base.expand(entrance.position)
	if level_exit != null:
		base = base.expand(level_exit.position)
	return base


# Anything falling below this is lost (cleanup of runaways). Derived from the
# playfield so tall custom levels don't kill lemmings mid-level.
func kill_plane_y() -> float:
	return get_terrain_bounds_px().end.y + 160.0


func world_to_tile(world_pos: Vector2) -> Vector2i:
	# floori (not int truncation) so negative world coordinates map correctly:
	# a lemming at x=-1 belongs to tile -1, not tile 0.
	return Vector2i(floori(world_pos.x / TILE_SIZE), floori(world_pos.y / TILE_SIZE))


func tile_to_world(tile_coord: Vector2i) -> Vector2:
	return Vector2(tile_coord.x * TILE_SIZE, tile_coord.y * TILE_SIZE)
