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
const BOMB_FUSE_SECONDS: float = 5.0

@export var direction: int = 1

var current_state: State = State.WALKING
var fall_start_y: float = 0.0
var fall_distance: float = 0.0
var is_floater: bool = false
var is_climber: bool = false
var bomb_timer: float = 0.0
var active_skill_node: RefCounted = null
var lemming_id: int = -1

@onready var body_visual: ColorRect = $Body
@onready var direction_indicator: ColorRect = $Direction


func _ready() -> void:
	add_to_group("lemmings")
	_update_visual()


func _physics_process(delta: float) -> void:
	if GameManager.current_state == GameManager.GameState.PAUSED:
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


func _process_walking(delta: float) -> void:
	velocity.y = GRAVITY
	velocity.x = WALK_SPEED * direction
	move_and_slide()
	if not is_on_floor():
		change_state(State.FALLING)
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col == null:
			continue
		var n: Vector2 = col.get_normal()
		if abs(n.x) > 0.5:
			var blocker_hit: bool = _is_blocker_at_front()
			if is_climber and not blocker_hit:
				change_state(State.CLIMBING)
				return
			turn_around()
			return


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
		change_state(State.WALKING)
		global_position.x += direction * 4


func _process_blocking(_delta: float) -> void:
	velocity = Vector2.ZERO


func _process_skill(_delta: float) -> void:
	if active_skill_node and active_skill_node.has_method("tick"):
		active_skill_node.tick(self)


func _process_exploding(delta: float) -> void:
	bomb_timer -= delta
	if bomb_timer <= 0.0:
		if active_skill_node and active_skill_node.has_method("detonate"):
			active_skill_node.detonate(self)
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
		var dx: float = lem.global_position.x - global_position.x
		if abs(dx) < 12 and sign(dx) == direction:
			return true
	return false


func _has_wall_at_side() -> bool:
	var space := get_world_2d().direct_space_state
	var from: Vector2 = global_position
	var to: Vector2 = global_position + Vector2(direction * 10, 0)
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collide_with_bodies = true
	query.exclude = [self]
	var result := space.intersect_ray(query)
	return not result.is_empty()


func turn_around() -> void:
	direction = -direction
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
	if body_visual == null:
		return
	match current_state:
		State.WALKING:
			body_visual.color = Color(0.2, 0.7, 0.2)
		State.FALLING:
			body_visual.color = Color(0.6, 0.6, 0.2)
		State.FLOATING:
			body_visual.color = Color(0.3, 0.8, 0.8)
		State.CLIMBING:
			body_visual.color = Color(0.8, 0.5, 0.2)
		State.BLOCKING:
			body_visual.color = Color(0.8, 0.2, 0.2)
		State.BUILDING:
			body_visual.color = Color(0.9, 0.7, 0.3)
		State.BASHING, State.MINING, State.DIGGING:
			body_visual.color = Color(0.5, 0.3, 0.7)
		State.EXPLODING:
			body_visual.color = Color(1.0, 0.3, 0.3)
		_:
			body_visual.color = Color(0.4, 0.4, 0.4)
	if direction_indicator:
		direction_indicator.position.x = 8 if direction > 0 else 0
