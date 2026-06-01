extends Control

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var level_select_button: Button = $CenterContainer/VBoxContainer/LevelSelectButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton


func _ready() -> void:
	play_button.pressed.connect(_on_play)
	level_select_button.pressed.connect(_on_select)
	quit_button.pressed.connect(_on_quit)


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _on_select() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/level_select.tscn")


func _on_quit() -> void:
	get_tree().quit()
