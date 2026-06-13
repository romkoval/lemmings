class_name LemmingSprite
extends Node2D

# A detailed, fully procedural lemming — no sprite sheets. Drawn each frame in
# local space with the feet at the origin (y grows downward into the body as
# negative y), posed by `state` and animated by an internal visual clock. The
# parent Lemming sets `state` and `dir`; tinting (highlight, bomb flash) rides
# on the node's `modulate`, so the sim is never touched by the visuals.
#
# Authored facing right; `dir < 0` mirrors every point through `_p()`.

const HAIR := Color(0.36, 0.86, 0.32)
const HAIR_D := Color(0.20, 0.62, 0.22)
const SKIN := Color(0.98, 0.80, 0.62)
const SKIN_D := Color(0.85, 0.62, 0.45)
const ROBE := Color(0.32, 0.44, 0.95)
const ROBE_D := Color(0.18, 0.26, 0.66)
const ROBE_HI := Color(0.55, 0.66, 1.0)
const BOOT := Color(0.85, 0.55, 0.20)
const EYE := Color(0.08, 0.06, 0.12)
const TOOL := Color(0.80, 0.82, 0.88)

var state: int = 0:
	set(v):
		state = v
		queue_redraw()
var dir: int = 1:
	set(v):
		dir = v
		queue_redraw()

var _t: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)


func _process(delta: float) -> void:
	# Visual-only clock (independent of the fixed sim tick — safe for replays).
	_t += delta
	queue_redraw()


# Author points facing right; mirror horizontally for a left-facing lemming.
func _p(x: float, y: float) -> Vector2:
	return Vector2(x * float(dir), y)


func _limb(a: Vector2, b: Vector2, col: Color, w: float = 2.6) -> void:
	draw_line(a, b, col, w)


func _draw() -> void:
	match state:
		Lemming.State.FALLING:    _draw_falling()
		Lemming.State.FLOATING:   _draw_floating()
		Lemming.State.CLIMBING:   _draw_climbing()
		Lemming.State.BLOCKING:   _draw_blocking()
		Lemming.State.BUILDING:   _draw_building()
		Lemming.State.BASHING:    _draw_bashing()
		Lemming.State.MINING:     _draw_mining()
		Lemming.State.DIGGING:    _draw_digging()
		Lemming.State.EXPLODING:  _draw_panic()
		Lemming.State.EXITED:     _draw_cheer()
		Lemming.State.SPLAT, Lemming.State.DYING: _draw_splat()
		_:                        _draw_walking()


# ── Shared body parts (feet at y≈0, head near y≈-15) ─────────────────────────

func _draw_torso(lean: float = 0.0) -> void:
	# Robe: a trapezoid, wider at the hem, with a shaded right edge + lit left
	# edge. Vertices are wound around the perimeter (no self-intersection).
	var sh := lean   # horizontal shoulder offset for a lean
	draw_colored_polygon(PackedVector2Array([
		_p(-5, -3), _p(5, -3), _p(3.4 + sh, -12.5), _p(-3.4 + sh, -12.5)]), ROBE)
	# Right (shaded) strip: outer-bottom → inner-bottom → inner-top → outer-top.
	draw_colored_polygon(PackedVector2Array([
		_p(5, -3), _p(3.0, -3), _p(1.4 + sh, -12.5), _p(3.4 + sh, -12.5)]), ROBE_D)
	# Left (lit) strip: outer-top → inner-top → inner-bottom → outer-bottom.
	draw_colored_polygon(PackedVector2Array([
		_p(-3.4 + sh, -12.5), _p(-1.4 + sh, -12.5), _p(-3.0, -3), _p(-5, -3)]), ROBE_HI)


func _draw_head(cx: float, cy: float, look: float = 1.0) -> void:
	draw_circle(_p(cx, cy), 3.4, SKIN)
	draw_circle(_p(cx + 1.4, cy - 0.6), 3.0, SKIN)   # rounder cheek
	# Hair: a green tuft sweeping back over the crown.
	draw_colored_polygon(PackedVector2Array([
		_p(cx - 3.2, cy - 1.6), _p(cx + 2.6, cy - 4.6), _p(cx + 3.4, cy - 2.0),
		_p(cx + 1.0, cy - 1.0), _p(cx - 3.4, cy - 0.2)]), HAIR)
	draw_colored_polygon(PackedVector2Array([
		_p(cx - 3.2, cy - 1.6), _p(cx - 1.2, cy - 3.0), _p(cx - 3.6, cy + 0.2)]), HAIR_D)
	# Eye, looking in the travel direction.
	draw_circle(_p(cx + 1.9 * look, cy - 0.2), 0.8, EYE)


func _draw_legs_walk() -> void:
	var swing: float = sin(_t * 11.0) * 2.6
	_limb(_p(-1.5, -3.5), _p(-1.8 + swing, 0.0), ROBE_D, 2.6)
	_limb(_p(1.5, -3.5), _p(1.8 - swing, 0.0), ROBE_D, 2.6)
	draw_circle(_p(-1.8 + swing, 0.2), 1.5, BOOT)
	draw_circle(_p(1.8 - swing, 0.2), 1.5, BOOT)


func _draw_legs_together(spread: float = 1.6) -> void:
	_limb(_p(-1.0, -3.5), _p(-spread, 0.0), ROBE_D, 2.6)
	_limb(_p(1.0, -3.5), _p(spread, 0.0), ROBE_D, 2.6)
	draw_circle(_p(-spread, 0.2), 1.5, BOOT)
	draw_circle(_p(spread, 0.2), 1.5, BOOT)


# ── Per-state poses ──────────────────────────────────────────────────────────

func _draw_walking() -> void:
	_draw_legs_walk()
	_draw_torso()
	var arm: float = sin(_t * 11.0) * 2.0
	_limb(_p(0, -10.5), _p(3.5, -6.0 + arm), SKIN, 2.2)   # forward arm swings
	_limb(_p(0, -10.5), _p(-2.6, -6.0 - arm), SKIN_D, 2.2)
	_draw_head(1.2, -15.0, 1.0)


func _draw_falling() -> void:
	_draw_legs_together(1.4)
	_draw_torso()
	# Arms thrown up.
	_limb(_p(0, -11), _p(-4.0, -15.5), SKIN, 2.2)
	_limb(_p(0, -11), _p(4.0, -15.5), SKIN, 2.2)
	_draw_head(0.6, -14.5, 0.4)


func _draw_floating() -> void:
	# Umbrella canopy above, held by both raised arms.
	var sway: float = sin(_t * 3.0) * 1.5
	var top := _p(sway, -26.0)
	draw_colored_polygon(PackedVector2Array([
		_p(-9 + sway, -22.0), _p(9 + sway, -22.0), top]), Color(0.90, 0.30, 0.32))
	for k in range(-2, 3):
		_limb(_p(k * 4.5 + sway, -22.0), top, Color(0.6, 0.15, 0.18), 1.0)
	_limb(top, _p(sway * 0.4, -12.0), Color(0.5, 0.4, 0.3), 1.4)   # shaft
	_draw_legs_together(1.4)
	_draw_torso()
	_limb(_p(0, -11), _p(-3.0 + sway, -19.0), SKIN, 2.0)
	_limb(_p(0, -11), _p(3.0 + sway, -19.0), SKIN, 2.0)
	_draw_head(0.6, -14.5, 0.4)


func _draw_climbing() -> void:
	# Hugging the wall ahead: body upright, hands reaching up alternately.
	var reach: float = sin(_t * 8.0) * 2.0
	_limb(_p(2.0, -3.5), _p(3.0, 0.0), ROBE_D, 2.6)
	_limb(_p(2.5, -3.5), _p(3.2, -1.0), ROBE_D, 2.6)
	_draw_torso(1.6)
	_limb(_p(2.0, -10.5), _p(4.5, -15.0 + reach), SKIN, 2.2)
	_limb(_p(2.0, -8.5), _p(4.5, -12.0 - reach), SKIN_D, 2.2)
	_draw_head(2.6, -15.0, 1.0)


func _draw_blocking() -> void:
	_draw_legs_together(3.0)
	_draw_torso()
	# Both arms straight out — "stop".
	_limb(_p(0, -9.5), _p(-6.0, -9.5), SKIN, 2.4)
	_limb(_p(0, -9.5), _p(6.0, -9.5), SKIN, 2.4)
	_draw_head(0.0, -15.0, 0.0)


func _draw_building() -> void:
	# Bent forward laying a plank; a fresh plank sits at the feet ahead.
	var place: float = 0.5 + 0.5 * sin(_t * 7.0)
	var plank_x: float = 2.0 if dir > 0 else -9.0
	draw_rect(Rect2(plank_x, -1.0, 7.0, 2.5), Color(0.62, 0.42, 0.22))
	_draw_legs_together(1.8)
	_draw_torso(1.0)
	_limb(_p(0, -10.5), _p(5.0, -6.0 + place * 4.0), SKIN, 2.2)
	_draw_head(1.8, -14.5, 1.0)


func _draw_bashing() -> void:
	# Sideways swing: forward arm chops horizontally back and forth.
	var swing: float = sin(_t * 12.0) * 3.0
	_draw_legs_together(2.2)
	_draw_torso(1.0)
	_limb(_p(0, -9.5), _p(6.5, -8.0 + swing), SKIN, 2.4)
	draw_circle(_p(6.5, -8.0 + swing), 1.4, SKIN)
	_draw_head(1.6, -14.5, 1.0)


func _draw_mining() -> void:
	# Pickaxe swung down-forward at 45°.
	var swing: float = 0.5 + 0.5 * sin(_t * 9.0)
	_draw_legs_together(2.0)
	_draw_torso(0.8)
	var hand := _p(5.0 + swing * 2.0, -3.0 + swing * 3.0)
	_limb(_p(0, -10.0), hand, SKIN, 2.2)
	# Pickaxe head jutting past the hand, down-forward.
	_limb(hand, hand + _p(4.0, 2.0), TOOL, 1.6)
	_draw_head(1.6, -14.5, 1.0)


func _draw_digging() -> void:
	# Digging straight down: the body bobs, both arms scoop down alternately.
	var bob: float = absf(sin(_t * 9.0)) * 1.6
	var scoop: float = sin(_t * 9.0) * 1.6
	draw_set_transform(Vector2(0, bob))
	_draw_legs_together(2.4)
	_draw_torso()
	_limb(_p(0, -9.0), _p(-3.0, -2.0 + scoop), SKIN, 2.2)
	_limb(_p(0, -9.0), _p(3.0, -2.0 - scoop), SKIN_D, 2.2)
	_draw_head(0.4, -14.5, 0.4)
	draw_set_transform(Vector2.ZERO)


func _draw_panic() -> void:
	# "Oh no!" — arms flung up, looking out. (Tint pulses via modulate.)
	var shake: float = sin(_t * 30.0) * 0.8
	_draw_legs_together(2.0)
	_draw_torso()
	_limb(_p(0, -11), _p(-4.5 + shake, -16.0), SKIN, 2.2)
	_limb(_p(0, -11), _p(4.5 + shake, -16.0), SKIN, 2.2)
	_draw_head(shake, -15.0, 0.0)


func _draw_cheer() -> void:
	_draw_legs_together(1.6)
	_draw_torso()
	_limb(_p(0, -11), _p(-3.5, -16.5), SKIN, 2.2)
	_limb(_p(0, -11), _p(3.5, -16.5), SKIN, 2.2)
	_draw_head(0.0, -15.0, 1.0)


func _draw_splat() -> void:
	# Flattened — a sad pancake with the green tuft splayed.
	draw_colored_polygon(PackedVector2Array([
		_p(-8, 0), _p(8, 0), _p(6, -3.2), _p(-6, -3.2)]), ROBE)
	draw_circle(_p(-3.0, -2.0), 2.4, SKIN)
	draw_colored_polygon(PackedVector2Array([
		_p(2.0, -1.0), _p(8.0, -2.6), _p(7.0, -0.2)]), HAIR)
