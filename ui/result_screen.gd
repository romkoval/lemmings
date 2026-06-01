class_name ResultScreen
extends Control

signal retry_pressed()
signal menu_pressed()

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var stats_label: Label = $Panel/VBox/StatsLabel
@onready var retry_button: Button = $Panel/VBox/HBox/RetryButton
@onready var menu_button: Button = $Panel/VBox/HBox/MenuButton


func _ready() -> void:
	retry_button.pressed.connect(func(): retry_pressed.emit())
	menu_button.pressed.connect(func(): menu_pressed.emit())
	visible = false


func show_result(success: bool, saved: int, required: int, total: int) -> void:
	if success:
		title_label.text = "ПОБЕДА!"
		title_label.modulate = Color(0.4, 1.0, 0.4)
	else:
		title_label.text = "ПОРАЖЕНИЕ"
		title_label.modulate = Color(1.0, 0.4, 0.4)
	stats_label.text = "Спасено: %d из %d\nЦель: %d" % [saved, total, required]
	visible = true
