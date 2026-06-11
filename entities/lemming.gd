class_name Lemming
extends CharacterBody2D

# Movement is classic Lemmings pixel physics: the body is a single probe column
# at its centre, the terrain is a 1px solidity mask (Level.is_solid_px), and all
# motion is whole-pixel stepping — walk 1px/frame, climb small rises, follow
# small drops, fall straight down. Godot physics is NOT used for terrain (no
# move_and_slide, no rays); the CharacterBody2D base remains only so Area2D
# triggers (exit, traps) keep detecting the body.

signal state_changed(old_state: State, new_state: State)
signal lemming_saved(lemming: Lemming)
signal lemming_died(lemming: Lemming, cause: String)

enum State {
	WALKING,
	FALLING,
	FLOATING,
	CLIMBING,
	BLOCKING,
	BUILDING,
	BASHING,
	MINING,
	DIGGING,
	EXPLODING,
	DYING,
	EXITED,
	SPLAT,
}

const WALK_SPEED: float = 60.0          # px/sec (1px per 60fps frame)
const MAX_FALL_PIXELS: int = 64
# Highest ledge a walker mounts in stride (builder planks are 8px); anything
# taller is a wall → turn or climb.
const STEP_UP_MAX: int = 8
# Deepest drop followed in stride (descending stairs); deeper → FALLING.
const STEP_DOWN_MAX: int = 8
const FALL_PX_PER_FRAME: int = 2        # 120 px/sec
const FLOAT_FALL_PER_FRAME: float = 0.6
const FLOAT_DRIFT_PER_FRAME: float = 0.25
const CLIMB_PX_PER_FRAME: float = 0.5   # 30 px/sec
const BOMB_FUSE_SECONDS: float = 5.0
# Anything that falls past the bottom of the playfield is lost (ТЗ §1.3).
const KILL_PLANE_Y: float = 1280.0

const TERMINAL_STATES: Array = [State.EXITED, State.DYING, State.SPLAT]

@export var direction: int = 1

var current_state: State = State.WALKING
var fall_start_y: float = 0.0
var fall_distance: float = 0.0
var is_floater: bool = false
var is_climber: bool = false
var bomb_timer: float = 0.0
var active_skill_node: RefCounted = null
var lemming_id: int = -1
var highlighted: bool = false

var _level_ref: Level = null
var _float_fall_acc: float = 0.0
var _float_drift_acc: float = 0.0
var _climb_acc: float = 0.0

@onready var sprite: AnimatedSprite2D = get_node_or_null("Sprite")


func _ready() -> void:
	add_to_group("lemmings")
	_update_visual()


func _physics_process(delta: float) -> void:
	# Freeze while paused or after the level has resolved (result screen up).
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	# Fell off the bottom of the world — count as lost so the level can resolve.
	if current_state not in TERMINAL_STATES and global_position.y > KILL_PLANE_Y:
		die("fell_out")
		return
	match current_state:
		State.WALKING:
			_process_walking(delta)
		State.FALLING:
			_process_falling(delta)
		State.FLOATING:
			_process_floating(delta)
		State.CLIMBING:
			_process_climbing(delta)
		State.BLOCKING:
			_process_blocking(delta)
		State.BUILDING, State.BASHING, State.MINING, State.DIGGING:
			_process_skill(delta)
		State.EXPLODING:
			_process_exploding(delta)
		State.DYING, State.EXITED, State.SPLAT:
			pass


func change_state(new_state: State) -> void:
	if new_state == current_state:
		return
	var old: State = current_state
	current_state = new_state
	state_changed.emit(old, new_state)
	_update_visual()
	if new_state == State.FALLING:
		fall_start_y = global_position.y
		fall_distance = 0.0


# ── Pixel probes ─────────────────────────────────────────────────────────────
# Feet = the pixel the lemming stands ON: centre column, 16px below the origin.

func _lv() -> Level:
	if _level_ref == null or not is_instance_valid(_level_ref):
		var node: Node = get_parent()
		while node:
			if node is Level:
				_level_ref = node
				break
			node = node.get_parent()
	return _level_ref


func _solid(x: int, y: int) -> bool:
	var lv: Level = _lv()
	return lv != null and lv.is_solid_px(Vector2(float(x) + 0.5, float(y) + 0.5))


func feet_x() -> int:
	return floori(global_position.x) + 8


func feet_y() -> int:
	return floori(global_position.y) + 16


func _set_feet(fx: int, fy: int) -> void:
	global_position = Vector2(float(fx - 8), float(fy - 16))


# If the torso ends up inside solid ground (someone built/stamped terrain over
# this lemming), pop straight up onto the surface. Capped so a fully entombed
# body doesn't teleport through a thick ceiling in one frame.
func _unbury() -> void:
	var fx: int = feet_x()
	var fy: int = feet_y()
	if not _solid(fx, fy - 3):
		return
	var y: int = fy
	var lift: int = 0
	while lift < 20 and _solid(fx, y - 3):
		y -= 1
		lift += 1
	if lift < 20:
		_set_feet(fx, y)


# ── States ───────────────────────────────────────────────────────────────────

func _process_walking(_delta: float) -> void:
	# A blocker stops walkers by proximity, not by collision (lemmings never
	# collide with each other). A builder ahead counts too — followers bump into
	# it and turn instead of overtaking onto the unfinished end and dropping
	# off (they pace behind and climb once the staircase is done).
	if _is_blocker_at_front() or _is_builder_at_front():
		turn_around()
		return
	_unbury()
	var fx: int = feet_x()
	var fy: int = feet_y()
	# Settle onto the ground at the current column first (terrain may have been
	# carved from under us, or we just mantled/landed slightly above it).
	if not _solid(fx, fy):
		var dn: int = 1
		while dn <= STEP_DOWN_MAX and not _solid(fx, fy + dn):
			dn += 1
		if dn > STEP_DOWN_MAX:
			change_state(State.FALLING)
			return
		fy += dn
		_set_feet(fx, fy)
	# One pixel of travel per frame.
	var nx: int = fx + direction
	var nfy: int = fy
	if _solid(nx, nfy - 1):
		# Ground rises ahead: find the new surface, ≤ STEP_UP_MAX or it's a wall.
		var top: int = nfy - 1
		while _solid(nx, top - 1) and (nfy - top) <= STEP_UP_MAX:
			top -= 1
		var rise: int = nfy - top
		if rise > STEP_UP_MAX:
			if is_climber:
				change_state(State.CLIMBING)
				return
			turn_around()
			return
		nfy = top
	elif not _solid(nx, nfy):
		# Ground drops ahead: follow it down a little, or start falling.
		var dn2: int = 1
		while dn2 <= STEP_DOWN_MAX and not _solid(nx, nfy + dn2):
			dn2 += 1
		if dn2 > STEP_DOWN_MAX:
			_set_feet(nx, nfy)
			change_state(State.FALLING)
			return
		nfy += dn2
	_set_feet(nx, nfy)


func _process_falling(_delta: float) -> void:
	# A floater opens its parachute the instant it starts falling — whether the
	# skill was given mid-air or earlier while walking.
	if is_floater:
		change_state(State.FLOATING)
		return
	var fx: int = feet_x()
	var fy: int = feet_y()
	for _i in range(FALL_PX_PER_FRAME):
		if _solid(fx, fy + 1):
			_set_feet(fx, fy)
			fall_distance = global_position.y - fall_start_y
			if fall_distance > float(MAX_FALL_PIXELS):
				die("splat")
				change_state(State.SPLAT)
			else:
				change_state(State.WALKING)
			return
		fy += 1
	_set_feet(fx, fy)
	fall_distance = global_position.y - fall_start_y


func _process_floating(_delta: float) -> void:
	var fx: int = feet_x()
	var fy: int = feet_y()
	_float_drift_acc += FLOAT_DRIFT_PER_FRAME
	if _float_drift_acc >= 1.0:
		_float_drift_acc -= 1.0
		if not _solid(fx + direction, fy - 8):
			fx += direction
	_float_fall_acc += FLOAT_FALL_PER_FRAME
	while _float_fall_acc >= 1.0:
		_float_fall_acc -= 1.0
		if _solid(fx, fy + 1):
			_set_feet(fx, fy)
			change_state(State.WALKING)
			return
		fy += 1
	_set_feet(fx, fy)


func _process_climbing(_delta: float) -> void:
	var fx: int = feet_x()
	var fy: int = feet_y()
	var wx: int = fx + direction   # the wall column being scaled
	if not _solid(wx, fy - 1):
		# Cleared the lip — mantle onto the surface and walk on.
		var g: int = fy - 1
		var down: int = 0
		while not _solid(wx, g + 1) and down < STEP_DOWN_MAX:
			g += 1
			down += 1
		_set_feet(wx, g)
		change_state(State.WALKING)
		return
	_climb_acc += CLIMB_PX_PER_FRAME
	while _climb_acc >= 1.0:
		_climb_acc -= 1.0
		fy -= 1
	_set_feet(fx, fy)


func _process_blocking(_delta: float) -> void:
	# A blocker holds its post but must still respect gravity: if the ground is
	# dug away beneath it, it falls instead of hanging in the air.
	_unbury()
	var fx: int = feet_x()
	var fy: int = feet_y()
	if _solid(fx, fy):
		return
	# Tolerate the ground surface being shaved a couple px lower (digger rows).
	for dn in range(1, 3):
		if _solid(fx, fy + dn):
			_set_feet(fx, fy + dn)
			return
	change_state(State.FALLING)


func _process_skill(_delta: float) -> void:
	if active_skill_node and active_skill_node.has_method("tick"):
		active_skill_node.tick(self)


func _process_exploding(delta: float) -> void:
	bomb_timer -= delta
	# Keep obeying gravity while the fuse burns; walk is frozen.
	var fx: int = feet_x()
	var fy: int = feet_y()
	if not _solid(fx, fy):
		for _i in range(FALL_PX_PER_FRAME):
			if _solid(fx, fy + 1):
				break
			fy += 1
		_set_feet(fx, fy)
	if sprite:
		var phase: float = fposmod(bomb_timer, 0.5)
		sprite.modulate = Color(1.0, 0.4, 0.4) if phase > 0.25 else Color(1.0, 1.0, 0.4)
	if bomb_timer <= 0.0:
		if active_skill_node and active_skill_node.has_method("detonate"):
			active_skill_node.detonate(self)
		AudioManager.play_sfx("explosion")
		die("bomb")


# ── Lemming-vs-lemming proximity (no physical collision) ────────────────────

func _is_blocker_at_front() -> bool:
	for other in get_tree().get_nodes_in_group("lemmings"):
		if other == self:
			continue
		var lem := other as Lemming
		if lem == null:
			continue
		if lem.current_state != State.BLOCKING:
			continue
		# Must be on the same level: a blocker one row up or down shouldn't stop
		# a lemming passing beneath/above it. 12px ≈ ¾ of a body of tolerance.
		var dy: float = lem.global_position.y - global_position.y
		if abs(dy) >= 12:
			continue
		var dx: float = lem.global_position.x - global_position.x
		if abs(dx) < 12 and sign(dx) == direction:
			return true
	return false


# A walker bumping into a building lemming ahead turns around — whichever way
# the builder faces. Without this, followers overtake the builder, walk off the
# unfinished staircase end and get stranded (or splat) below; with it they pace
# behind the builder and climb once the staircase is complete, like the
# original game's crowds.
func _is_builder_at_front() -> bool:
	for other in get_tree().get_nodes_in_group("lemmings"):
		if other == self:
			continue
		var lem := other as Lemming
		if lem == null or lem.current_state != State.BUILDING:
			continue
		var dy: float = lem.global_position.y - global_position.y
		if abs(dy) >= 12:
			continue
		var dx: float = lem.global_position.x - global_position.x
		if abs(dx) < 12 and signf(dx) == direction:
			return true
	return false


# ── Misc ─────────────────────────────────────────────────────────────────────

func turn_around() -> void:
	direction = -direction
	_update_visual()


func set_highlighted(value: bool) -> void:
	if highlighted == value:
		return
	highlighted = value
	_update_visual()


func assign_skill(skill) -> bool:
	if skill == null:
		return false
	if not skill.has_method("can_apply") or not skill.can_apply(self):
		return false
	active_skill_node = skill
	skill.apply(self)
	return true


func start_bomb_countdown() -> void:
	bomb_timer = BOMB_FUSE_SECONDS
	change_state(State.EXPLODING)


func mark_saved() -> void:
	change_state(State.EXITED)
	lemming_saved.emit(self)
	GameManager.notify_lemming_saved()
	queue_free()


func die(cause: String) -> void:
	lemming_died.emit(self, cause)
	GameManager.notify_lemming_died()
	AudioManager.play_sfx("oh_no")
	queue_free()


func _update_visual() -> void:
	if sprite == null:
		return
	# Sprite art faces right by default; flip when walking left.
	sprite.flip_h = direction < 0
	# Reset bomb-flash tint when leaving EXPLODING; the bomb flash owns the tint.
	if current_state != State.EXPLODING:
		# Highlight the lemming the player is about to assign a skill to.
		sprite.modulate = Color(1.7, 1.7, 0.7) if highlighted else Color(1, 1, 1, 1)
	var anim: StringName = &"walk"
	match current_state:
		State.WALKING:    anim = &"walk"
		State.FALLING:    anim = &"fall"
		State.FLOATING:   anim = &"float"
		State.CLIMBING:   anim = &"climb"
		State.BLOCKING:   anim = &"block"
		State.BUILDING:   anim = &"build"
		State.BASHING:    anim = &"bash"
		State.MINING:     anim = &"mine"
		State.DIGGING:    anim = &"dig"
		State.EXPLODING:  anim = &"bomb"
		State.EXITED:     anim = &"exit"
		State.SPLAT, State.DYING: anim = &"die"
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
