class_name BuilderSkill
extends BaseSkill

# Builder lays a diagonal bridge as a run of separate wooden PLANKS. Each plank is
# a 16×8 rectangle (Sprite2D overlay) laid one at a time: the next plank sits 8px
# higher and overlaps the last, so a full 16×16 cell of structure is built from
# TWO planks — i.e. one square per two movements. The walk collision is a
# transparent full-cell tile stamped once per finished square (every 2nd plank),
# so the geometry lemmings climb is unchanged while the visible bridge is the
# overlapping planks.
const MAX_STEPS: int = 12               # full 16×16 squares of reach
const MAX_PLANKS: int = MAX_STEPS * 2   # two planks per square
const TICKS_PER_PLANK: int = 22         # climb + brief hold per plank (deliberate pace)
const CLIMB_TICKS: int = 14
const PLANK_H: int = 8                  # half a cell
# Transparent collision tiles (full-cell polygon) under the visible plank sprites.
const PLANK_ATLAS_R: Vector2i = Vector2i(2, 1)
const PLANK_ATLAS_L: Vector2i = Vector2i(3, 1)
const PLANK_TEX: Texture2D = preload("res://assets/sprites/plank.png")

var steps_placed: int = 0               # finished 16×16 squares (collision cells)
var planks_laid: int = 0                # individual plank rectangles laid
var _start_tile: Vector2i = Vector2i.ZERO
var _start_dir: int = 1
var _start_pos: Vector2 = Vector2.ZERO  # lemming origin when building began
var _moving: bool = false
var _move_t: int = 0
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO


func get_skill_name() -> String:
	return "builder"


func can_apply(lemming: Lemming) -> bool:
	return lemming.current_state == Lemming.State.WALKING


func apply(lemming: Lemming) -> void:
	steps_placed = 0
	planks_laid = 0
	_moving = false
	_move_t = 0
	_start_dir = lemming.direction
	_start_pos = lemming.global_position
	var level: Level = _get_level(lemming)
	if level != null:
		# Floor tile under the leading foot, one row up = the cell the first square
		# of structure fills. Probe +18 (not +16): the body settles ~1px high, so
		# feet+16 would read the empty cell above and start a tile too high.
		var feet_world: Vector2 = lemming.global_position + Vector2(8 + _start_dir * 8, 18)
		var floor_tile: Vector2i = level.world_to_tile(feet_world)
		_start_tile = floor_tile + Vector2i(0, -1)
	lemming.change_state(Lemming.State.BUILDING)


func plank_atlas() -> Vector2i:
	return PLANK_ATLAS_R if _start_dir > 0 else PLANK_ATLAS_L


# Collision cell for the Nth finished square — 45° staircase, one cell up + over.
func _tile_for_step(n: int) -> Vector2i:
	return Vector2i(_start_tile.x + n * _start_dir, _start_tile.y - n)


# Lemming standing position once square m is finished (feet on top of cell m).
func _square_target(m: int) -> Vector2:
	var t: Vector2i = _tile_for_step(m)
	return Vector2(t.x * Level.TILE_SIZE, t.y * Level.TILE_SIZE - Level.TILE_SIZE)


# Top-left pixel position of plank k (0-based). Each plank is OFFSET from the last
# by half a cell up + half a cell in the build direction (8px, 8px), so the run
# reads as overlapping stair steps rather than a stack of squares. The +PLANK_H
# vertical bias drops plank 0 onto the floor (the staircase starts at the bottom,
# not a tile up) and centres the plank band on the 45° ramp collision surface so
# lemmings walk along the top of the steps instead of sinking into them.
func _plank_pos(k: int) -> Vector2:
	return Vector2(
		_start_tile.x * Level.TILE_SIZE + k * PLANK_H * _start_dir,
		_start_tile.y * Level.TILE_SIZE + PLANK_H - k * PLANK_H
	)


func _spawn_plank(level: Level, k: int) -> void:
	var spr := Sprite2D.new()
	spr.texture = PLANK_TEX
	spr.centered = false
	spr.flip_h = _start_dir < 0
	spr.position = _plank_pos(k)
	spr.z_index = 1                                   # above the terrain layer
	level.add_child(spr)


func tick(lemming: Lemming) -> void:
	# Phase 1: climb onto the plank just laid, then hold briefly.
	if _moving:
		_move_t += 1
		var f: float = clampf(float(_move_t) / float(CLIMB_TICKS), 0.0, 1.0)
		lemming.global_position = _from.lerp(_to, f)
		if _move_t >= TICKS_PER_PLANK:
			_moving = false
			if planks_laid >= MAX_PLANKS:
				lemming.change_state(Lemming.State.WALKING)
		return
	# Phase 2: lay the next plank.
	if planks_laid >= MAX_PLANKS:
		lemming.change_state(Lemming.State.WALKING)
		return
	var level: Level = _get_level(lemming)
	if level == null:
		lemming.change_state(Lemming.State.WALKING)
		return
	var k: int = planks_laid
	var m: int = k / 2
	if k % 2 == 0:
		# Lower plank = start of a new square. Stamp the collision cell NOW (not on
		# the second plank) so followers climbing right behind always have the next
		# step to land on instead of walking off the edge into the gap.
		if level.is_solid_at(_tile_for_step(m)):
			lemming.change_state(Lemming.State.WALKING)
			return
		_spawn_plank(level, k)
		level.add_terrain_at(_tile_for_step(m), Level.DIRT_SOURCE, plank_atlas())
		steps_placed += 1
	else:
		# Upper plank = purely visual, fills the top half of the square.
		_spawn_plank(level, k)
	# Move the lemming half a square per plank: even k climbs to the midpoint of
	# square m, odd k finishes square m.
	var prev_target: Vector2 = _square_target(m - 1) if m > 0 else _start_pos
	var sq_target: Vector2 = _square_target(m)
	_from = lemming.global_position
	_to = prev_target.lerp(sq_target, 0.5) if (k % 2 == 0) else sq_target
	_moving = true
	_move_t = 0
	planks_laid += 1
