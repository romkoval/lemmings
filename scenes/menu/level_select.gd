extends Control

const CATEGORIES: Array[String] = ["fun"]

@onready var list_container: VBoxContainer = $ScrollContainer/VBoxContainer
@onready var back_button: Button = $BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back)
	_populate()


func _populate() -> void:
	for child in list_container.get_children():
		child.queue_free()
	for category in CATEGORIES:
		var header := Label.new()
		header.text = category.to_upper()
		header.add_theme_font_size_override("font_size", 28)
		list_container.add_child(header)
		var json_files: Array = LevelManager.list_levels(category)
		for fname in json_files:
			var level_num: int = int(fname.replace("level_", "").replace(".json", ""))
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(0, 56)
			var level_id: String = "%s_%02d" % [category, level_num]
			var done: String = " ✓" if SaveManager.is_level_complete(level_id) else ""
			btn.text = "Уровень %d%s" % [level_num, done]
			btn.pressed.connect(_on_pick.bind(category, level_num))
			list_container.add_child(btn)


func _on_pick(category: String, level_num: int) -> void:
	var scene_path: String = LevelManager.get_scene_path(category, level_num)
	if not ResourceLoader.exists(scene_path):
		push_warning("Scene not found: %s" % scene_path)
		return
	GameManager.current_level_id = "%s_%02d" % [category, level_num]
	var game_scene: PackedScene = load("res://scenes/game/game.tscn")
	var game := game_scene.instantiate()
	if "initial_level_path" in game:
		game.initial_level_path = scene_path
	get_tree().root.add_child(game)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = game


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
