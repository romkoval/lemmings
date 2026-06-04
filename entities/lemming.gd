class_name Lemming
extends CharacterBody2D

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

const WALK_SPEED: float = 60.0
const GRAVITY: float = 120.0
const MAX_FALL_PIXELS: int = 64
const CLIMB_SPEED: float = 30.0
# Downward bias applied while walking on the ground (see _process_walking). Much
# smaller than GRAVITY so 45° ramps remain climbable.
const GROUND_STICK: float = 20.0
const BOMB_FUSE_SECONDS: float = 5.0
# Anything that falls past the bottom of the playfield is lost (ТЗ §1.3).
# Without this a lemming that walks off the map falls forever and the level
# can never resolve.
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
# Gradual step-up onto a stair/terrain step (see _try_step_up): while true the
# body slides toward _step_target at walking speed instead of teleporting.
var _stepping_up: bool = false
var _step_target: Vector2 = Vector2.ZERO

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
	_stepping_up = false
	state_changed.emit(old, new_state)
	_update_visual()
	if new_state == State.FALLING:
		fall_start_y = global_position.y
		fall_distance = 0.0


func _process_walking(delta: float) -> void:
	# Mid-climb onto a step: slide toward the step top at walking speed and do
	# nothing else until we arrive (see _try_step_up / _advance_step_up).
	if _stepping_up:
		_advance_step_up(delta)
		return
	# A blocker stops walkers by proximity, not by physical collision: lemmings
	# share no collision mask with each other (mask = terrain only), so two bodies
	# pass straight through. Detect the blocker ahead and turn before moving. A
	# builder met head-on counts too (so a walker doesn't march through it), but a
	# follower coming up behind the builder is let past to climb the stairs.
	if _is_blocker_at_front() or _is_head_on_builder_at_front():
		turn_around()
		return
	# Only a small downward "stick" force while grounded — NOT full gravity. On a
	# 45° slope full gravity's down-slope component (≈0.7·GRAVITY) would overpower
	# the walk speed and the lemming could never climb; a light bias lets floor
	# snapping hug slopes while horizontal speed still carries it uphill.
	velocity.y = GROUND_STICK
	velocity.x = WALK_SPEED * direction
	move_and_slide()
	if not is_on_floor():
		change_state(State.FALLING)
		return
	# Walkable slopes are carried by move_and_slide as floor, so the lemming glides
	# up/down ramps. Only a *near-vertical* obstacle in the travel direction counts
	# as a wall — there we step up a single tile, climb, or turn. A 45° ramp normal
	# (n.y≈-0.7) is well clear of this test, so ramps never trigger a turn.
	if _hit_vertical_wall():
		if _is_blocker_at_front():
			turn_around()
			return
		# Try to step up over a 1-tile-high obstacle (e.g. builder stairs).
		if _try_step_up():
			return
		if is_climber:
			change_state(State.CLIMBING)
			return
		turn_around()
		return


# True only when a slide collision this frame is a near-vertical wall facing the
# lemming (steeper than any walkable slope), so ramps/floors don't count.
func _hit_vertical_wall() -> bool:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col == null:
			continue
		var n: Vector2 = col.get_normal()
		if absf(n.y) < 0.35 and absf(n.x) > 0.85 and signf(n.x) == -direction:
			return true
	return false


func _process_falling(delta: float) -> void:
	velocity.y = GRAVITY * 2.0
	velocity.x = 0
	move_and_slide()
	fall_distance = global_position.y - fall_start_y
	if is_on_floor():
		if fall_distance > MAX_FALL_PIXELS and not is_floater:
			die("splat")
			change_state(State.SPLAT)
		else:
			change_state(State.WALKING)


func _process_floating(delta: float) -> void:
	velocity.y = GRAVITY * 0.3
	velocity.x = WALK_SPEED * direction * 0.25
	move_and_slide()
	if is_on_floor():
		change_state(State.WALKING)


func _process_climbing(delta: float) -> void:
	velocity.y = -CLIMB_SPEED
	velocity.x = 0
	move_and_slide()
	if not _has_wall_at_side():
		# Reached the top — mantle over the edge onto the surface and resume
		# walking in the same direction. Lift clear of the lip and step forward
		# so the body lands on top instead of sliding back down the face.
		change_state(State.WALKING)
		global_position += Vector2(direction * 14, -10)


func _process_blocking(_delta: float) -> void:
	# A blocker holds its X but must still respect gravity: if the ground beneath
	# it is dug away it should fall, not hang in the air. Stick lightly to the
	# floor (so floor-snap keeps it put on slopes) and drop to FALLING the moment
	# there's nothing under it.
	velocity.x = 0.0
	velocity.y = GROUND_STICK
	move_and_slide()
	if not is_on_floor():
		change_state(State.FALLING)


func _process_skill(_delta: float) -> void:
	if active_skill_node and active_skill_node.has_method("tick"):
		active_skill_node.tick(self)


func _process_exploding(delta: float) -> void:
	bomb_timer -= delta
	velocity.y = GRAVITY
	velocity.x = WALK_SPEED * direction
	move_and_slide()
	if sprite:
		var phase: float = fposmod(bomb_timer, 0.5)
		sprite.modulate = Color(1.0, 0.4, 0.4) if phase > 0.25 else Color(1.0, 1.0, 0.4)
	if bomb_timer <= 0.0:
		if active_skill_node and active_skill_node.has_method("detonate"):
			active_skill_node.detonate(self)
		AudioManager.play_sfx("explosion")
		die("bomb")


func _is_blocker_at_front() -> bool:
	for other in get_tree().get_nodes_in_group("lemmings"):
		if other == self:
			continue
		var lem := other as Lemming
		if lem == null:
			continue
		if lem.current_state != State.BLOCKING:
			continue
		# Must be on the same level: a blocker one row up or down (≥ a tile away in
		# Y) shouldn't stop a lemming passing beneath/above it — only block walkers
		# sharing its ground. 12px ≈ ¾ of a 16px tile of vertical tolerance.
		var dy: float = lem.global_position.y - global_position.y
		if abs(dy) >= 12:
			continue
		var dx: float = lem.global_position.x - global_position.x
		if abs(dx) < 12 and sign(dx) == direction:
			return true
	return false


# A walker meeting a building lemming head-on (the builder is right in front and
# facing back toward this lemming) turns around, instead of walking through it.
# A follower approaching from behind (same facing) is NOT turned — it should walk
# up the staircase the builder is laying.
func _is_head_on_builder_at_front() -> bool:
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
		if abs(dx) < 12 and signf(dx) == direction and lem.direction == -direction:
			return true
	return false


func _has_wall_at_side() -> bool:
	# Cast from the body's leading edge (the collision box sits at x∈[3..13]
	# around the origin, so the wall a walker stops against is ~13px ahead of
	# the origin). A short ray from the origin would fall short of the wall and
	# make a climber drop off immediately — sample from the box centre with
	# enough reach to touch the wall the body is flush against.
	var space := get_world_2d().direct_space_state
	var origin: Vector2 = global_position + Vector2(8, 8)
	var result := _ray_hits(space, origin, Vector2(direction * 12, 0))
	if result:
		return true
	# Also check at head height so an overhang/ledge still counts as wall.
	return _ray_hits(space, global_position + Vector2(8, 2), Vector2(direction * 12, 0))


func _ray_hits(space: PhysicsDirectSpaceState2D, from: Vector2, offset: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, from + offset)
	query.collide_with_bodies = true
	query.exclude = [self]
	return not space.intersect_ray(query).is_empty()


func _get_level() -> Level:
	var node: Node = get_parent()
	while node:
		if node is Level:
			return node
		node = node.get_parent()
	return null


# Checks whether the cell directly in front (at body level) is a single solid
# tile with empty space above it. Used by step-up over builder stairs.
func can_step_up() -> bool:
	var level: Level = _get_level()
	if level == null or level.terrain_layer == null:
		return false
	# +18 (not +16): the body settles ~1px above the floor, so a +16 probe reads
	# the empty cell above the floor and a 1-tile step (e.g. a builder brick at
	# foot level) is missed. Probe a couple px into the floor for the true tile.
	var feet_world: Vector2 = global_position + Vector2(8 + direction * 8, 18)
	var feet_tile: Vector2i = level.world_to_tile(feet_world)
	var wall_tile: Vector2i = feet_tile + Vector2i(0, -1)
	if not level.is_solid_at(wall_tile):
		return false
	var above_tile: Vector2i = wall_tile + Vector2i(0, -1)
	if level.is_solid_at(above_tile):
		return false
	return true


func _try_step_up() -> bool:
	if not can_step_up():
		return false
	var level: Level = _get_level()
	var feet_world: Vector2 = global_position + Vector2(8 + direction * 8, 18)
	var wall_tile: Vector2i = level.world_to_tile(feet_world) + Vector2i(0, -1)
	var tile_left: float = float(wall_tile.x * Level.TILE_SIZE)
	var target_y: float = wall_tile.y * Level.TILE_SIZE - Level.TILE_SIZE
	# Land the body centre a few px onto the step from the side it entered, so it's
	# supported by the step tile instead of hovering beside it. Symmetric in both
	# directions (an absolute-tile-X snap jumped a full tile going right but barely
	# moved going left).
	var target_x: float = tile_left - 4.0 if direction > 0 else tile_left + 4.0
	# Climb onto the step gradually rather than teleporting: an instant jump moved
	# the body ~18px in one frame, so the crowd ascended a staircase about twice as
	# fast as they walk on flat ground. Sliding toward the step top at WALK_SPEED
	# keeps stair travel no faster than flat walking (_advance_step_up).
	_step_target = Vector2(target_x, target_y)
	_stepping_up = true
	return true


func _advance_step_up(delta: float) -> void:
	var to_target: Vector2 = _step_target - global_position
	var step_len: float = WALK_SPEED * delta
	if to_target.length() <= step_len:
		global_position = _step_target
		_stepping_up = false
	else:
		global_position += to_target.normalized() * step_len


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
