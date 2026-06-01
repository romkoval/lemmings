class_name Entrance
extends Node2D

signal lemming_spawned(lemming: Lemming)

const LEMMING_SCENE: PackedScene = preload("res://entities/lemming.tscn")

@export var initial_direction: int = 1
@export var spawn_offset: Vector2 = Vector2(0, 16)

var spawned_count: int = 0
var max_spawn: int = 0
var spawn_interval: float = 2.0
var time_since_spawn: float = 999.0
var is_active: bool = false


func configure(total: int, release_rate: int) -> void:
	max_spawn = total
	spawn_interval = clamp(remap(release_rate, 1.0, 99.0, 3.0, 0.3), 0.3, 3.0)
	spawned_count = 0
	time_since_spawn = spawn_interval
	is_active = true


func _process(delta: float) -> void:
	if not is_active:
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if spawned_count >= max_spawn:
		is_active = false
		return
	time_since_spawn += delta
	if time_since_spawn >= spawn_interval:
		_spawn()
		time_since_spawn = 0.0


func _spawn() -> void:
	var lem: Lemming = LEMMING_SCENE.instantiate()
	lem.global_position = global_position + spawn_offset
	lem.direction = initial_direction
	lem.lemming_id = spawned_count
	get_parent().add_child(lem)
	spawned_count += 1
	GameManager.notify_lemming_spawned()
	lemming_spawned.emit(lem)
