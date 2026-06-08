class_name DiggerSkill
extends BaseSkill

# Descend speed while digging straight down, in pixels per physics tick. 0.5px
# ≈ 30 px/s — half the 60 px/s walk speed, so a 16px block takes ~0.5s. The
# lemming sinks gradually through each block instead of whole tiles vanishing in
# an instant cascade.
const DIG_SPEED: float = 0.5

var _last_cleared: Vector2i = Vector2i(2147483647, 2147483647)


func get_skill_name() -> String:
	return "digger"


func can_apply(lemming: Lemming) -> bool:
	return lemming.current_state == Lemming.State.WALKING


func apply(lemming: Lemming) -> void:
	_last_cleared = Vector2i(2147483647, 2147483647)
	lemming.change_state(Lemming.State.DIGGING)


func tick(lemming: Lemming) -> void:
	var level: Level = _get_level(lemming)
	if level == null:
		lemming.change_state(Lemming.State.WALKING)
		return
	# Tile under the feet (body settles ~1px high, so probe +18 to hit the floor).
	var tile: Vector2i = level.world_to_tile(lemming.global_position + Vector2(8, 18))
	if level.is_steel_at(tile):
		lemming.change_state(Lemming.State.WALKING)
		return
	if level.is_terrain_at(tile):
		# Reached a fresh block — carve it once, then keep sinking through it.
		if tile != _last_cleared:
			level.remove_terrain_at(tile)
			_last_cleared = tile
	elif not level.is_solid_at(tile + Vector2i(0, 1)):
		# Current cell empty and nothing solid right below — broke through into
		# open space, so start falling.
		lemming.change_state(Lemming.State.FALLING)
		return
	# Sink gradually.
	lemming.global_position.y += DIG_SPEED
