class_name BuilderSkill
extends BaseSkill

# Lays a staircase of wooden planks directly INTO the pixel terrain: each plank
# is a 16×8 block of wood pixels, offset half a plank up and forward from the
# last, so a full body-height of rise takes two planks. Because planks are
# terrain pixels, they are walkable, drillable and bashable exactly like ground
# — visuals and collision are the same data by construction, so a "drilled but
# visible" or "visible but intangible" staircase cannot exist.

const MAX_PLANKS: int = 24              # 12 squares of reach, two planks each
const TICKS_PER_PLANK: int = 22         # climb + brief hold per plank
const CLIMB_TICKS: int = 14
const PLANK_W: int = 16
const PLANK_H: int = 8

var planks_laid: int = 0
var _dir: int = 1
var _base: Vector2i = Vector2i.ZERO     # top-left px of plank 0
var _feet0: Vector2i = Vector2i.ZERO    # feet px where building began
var _moving: bool = false
var _move_t: int = 0
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO


func get_skill_name() -> String:
	return "builder"


func can_apply(lemming: Lemming) -> bool:
	return lemming.current_state == Lemming.State.WALKING


func needs_tick() -> bool:
	return true


func apply(lemming: Lemming) -> void:
	planks_laid = 0
	_moving = false
	_move_t = 0
	_dir = lemming.direction
	_feet0 = Vector2i(lemming.feet_x(), lemming.feet_y())
	# Plank 0 rests on the floor at the feet, extending in the build direction —
	# the staircase starts at ground level.
	_base = Vector2i(_feet0.x if _dir > 0 else _feet0.x - PLANK_W, _feet0.y - PLANK_H)
	lemming.change_state(Lemming.State.BUILDING)


# Top-left px of plank k: half a plank forward and half a plank up per step.
func plank_rect(k: int) -> Rect2i:
	return Rect2i(_base.x + k * PLANK_H * _dir, _base.y - k * PLANK_H, PLANK_W, PLANK_H)


# Where the feet stand once plank k is laid: centred on it, on its top surface.
func _feet_target(k: int) -> Vector2i:
	return Vector2i(_feet0.x + _dir * PLANK_H * (k + 1), _feet0.y - PLANK_H * (k + 1))


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
	var land: Vector2i = _feet_target(k)
	# Blocked: standing room on the new plank is already occupied by terrain
	# (bridge ran into a wall/ceiling) — stop and walk.
	if level.is_solid_px(Vector2(land.x + 0.5, land.y - 3.5)) \
			or level.is_solid_px(Vector2(land.x + 0.5, land.y - 11.5)):
		lemming.change_state(Lemming.State.WALKING)
		return
	level.fill_rect_px(plank_rect(k), PixelTerrain.MAT_WOOD)
	_from = lemming.global_position
	_to = Vector2(float(land.x - 8), float(land.y - 16))
	_moving = true
	_move_t = 0
	planks_laid += 1
