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


func _solid(tile: Vector2i) -> void:
	_level.terrain_layer.set_cell(tile, 0, Vector2i.ZERO)


# Lemming at (80,448) facing right stands on row 29; its body is on row 28. The
# basher probes the cell just past its leading edge → tile (6, 28).
func test_basher_carves_two_row_tunnel_and_keeps_floor() -> void:
	_lemming.global_position = Vector2(80, 448)
	_lemming.direction = 1
	_solid(Vector2i(5, 29))  # floor under the lemming
	_solid(Vector2i(6, 29))  # floor ahead
	_solid(Vector2i(6, 28))  # wall at body height
	_solid(Vector2i(6, 27))  # wall at head height (one above)
	var skill: BasherSkill = BasherSkill.new()
	skill.apply(_lemming)
	for i in range(BasherSkill.TICKS_PER_DIG):
		skill.tick(_lemming)
	# Both the body row and the row above must clear, or the crowd's capsule (which
	# settles ~1px high) snags on the leftover sliver and can't pass through.
	assert_false(_level.is_terrain_at(Vector2i(6, 28)), "body row should be cleared")
	assert_false(_level.is_terrain_at(Vector2i(6, 27)), "head row should be cleared for clearance")
	# The floor must remain so lemmings can walk through the tunnel.
	assert_true(_level.is_terrain_at(Vector2i(6, 29)), "floor must be preserved")


func test_basher_stops_at_steel() -> void:
	_lemming.global_position = Vector2(80, 448)
	_lemming.direction = 1
	_solid(Vector2i(5, 29))
	_level.steel_layer.set_cell(Vector2i(6, 28), 1, Vector2i.ZERO)  # steel ahead
	var skill: BasherSkill = BasherSkill.new()
	skill.apply(_lemming)
	for i in range(BasherSkill.TICKS_PER_DIG):
		skill.tick(_lemming)
	assert_eq(_lemming.current_state, Lemming.State.WALKING, "basher gives up against steel")
	assert_true(_level.is_steel_at(Vector2i(6, 28)), "steel is never removed")
