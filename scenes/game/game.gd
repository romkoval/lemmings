class_name Game
extends Node2D

@export var initial_level_path: String = ""

@onready var level_container: Node2D = $LevelContainer
@onready var hud_layer: CanvasLayer = $HUDLayer

var current_level: Level = null
var lemming_manager: LemmingManager = null
var skill_manager: Node = null


func _ready() -> void:
	lemming_manager = LemmingManager.new()
	lemming_manager.name = "LemmingManager"
	add_child(lemming_manager)
	if ResourceLoader.exists("res://managers/skill_manager.gd"):
		var skill_script: Script = load("res://managers/skill_manager.gd")
		skill_manager = skill_script.new()
		skill_manager.name = "SkillManager"
		add_child(skill_manager)
	var path: String = initial_level_path
	if path == "":
		path = "res://levels/fun/level_01.tscn"
	if ResourceLoader.exists(path):
		load_level(path)


func load_level(scene_path: String) -> void:
	if current_level:
		current_level.queue_free()
	var scene: PackedScene = load(scene_path)
	if scene == null:
		return
	current_level = scene.instantiate() as Level
	level_container.add_child(current_level)
	lemming_manager.setup(current_level.total_lemmings)
	if skill_manager and skill_manager.has_method("configure"):
		skill_manager.configure(current_level.skill_counts)
	GameManager.start_level(current_level.level_id)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if GameManager.current_state == GameManager.GameState.PLAYING:
			GameManager.set_state(GameManager.GameState.PAUSED)
		elif GameManager.current_state == GameManager.GameState.PAUSED:
			GameManager.set_state(GameManager.GameState.PLAYING)
