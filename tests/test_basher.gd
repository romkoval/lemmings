extends "res://addons/gut/test.gd"

const LemmingScene: PackedScene = preload("res://entities/lemming.tscn")
const LevelScene: PackedScene = preload("res://scenes/game/level.tscn")

var _level: Level
var _lemming: Lemming


func before_each() -> void:
	_level = LevelScene.instantiate()
	add_child_autoqfree(_level)
	_lemming = LemmingScene.instantiate()
	_level.add_child(_lemming)
	autoqfree(_lemming)


func _block(tile: Vector2i, mat: float = PixelTerrain.MAT_DIRT) -> void:
	_level.fill_rect_px(Rect2i(tile * Level.TILE_SIZE, Vector2i(Level.TILE_SIZE, Level.TILE_SIZE)), mat)


# Lemming at (80,448) facing right: feet at (88, 464) on the floor row. The
# basher carves a body-height tunnel ahead, leaving the floor intact.
func test_basher_carves_tunnel_and_keeps_floor() -> void:
	_lemming.global_position = Vector2(80, 448)
	_lemming.direction = 1
	for x in range(5, 9):
		_block(Vector2i(x, 29))           # floor run
	_block(Vector2i(6, 28))               # wall at body height
	_block(Vector2i(6, 27))               # wall at head height
	var skill: BasherSkill = BasherSkill.new()
	skill.apply(_lemming)
	for i in range(BasherSkill.TICKS_PER_SWING + 1):
		skill.tick(_lemming)
	# Tunnel cleared through the wall at body and head height...
	assert_false(_level.is_solid_px(Vector2(100.5, 456.5)), "body height cleared")
	assert_false(_level.is_solid_px(Vector2(100.5, 448.5)), "head height cleared")
	# ...while the floor under the tunnel survives.
	assert_true(_level.is_solid_px(Vector2(100.5, 470.5)), "floor preserved")
	assert_eq(_lemming.current_state, Lemming.State.BASHING, "still bashing into the wall")


func test_basher_finishes_when_tunnel_opens() -> void:
	_lemming.global_position = Vector2(80, 448)
	_lemming.direction = 1
	for x in range(5, 9):
		_block(Vector2i(x, 29))
	_block(Vector2i(6, 28))               # one thin wall, then open air
	var skill: BasherSkill = BasherSkill.new()
	skill.apply(_lemming)
	# First swing carves the wall; a later swing meets nothing and stops.
	for i in range(BasherSkill.TICKS_PER_SWING * 4):
		skill.tick(_lemming)
		if _lemming.current_state != Lemming.State.BASHING:
			break
	assert_eq(_lemming.current_state, Lemming.State.WALKING, "resumed walking after the tunnel")


func test_basher_stops_at_steel() -> void:
	_lemming.global_position = Vector2(80, 448)
	_lemming.direction = 1
	_block(Vector2i(5, 29))
	_block(Vector2i(6, 28), PixelTerrain.MAT_STEEL)   # steel ahead at body height
	var skill: BasherSkill = BasherSkill.new()
	skill.apply(_lemming)
	for i in range(BasherSkill.TICKS_PER_SWING + 1):
		skill.tick(_lemming)
	assert_eq(_lemming.current_state, Lemming.State.WALKING, "basher gives up against steel")
	assert_true(_level.is_steel_px(Vector2(100.5, 456.5)), "steel is never removed")
