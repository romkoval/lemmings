class_name ResultScreen
extends Control

signal retry_pressed()
signal menu_pressed()
signal next_pressed()
signal replay_pressed()

var replay_button: Button = null

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var stats_label: Label = $Panel/VBox/StatsLabel
@onready var next_button: Button = $Panel/VBox/HBox/NextButton
@onready var retry_button: Button = $Panel/VBox/HBox/RetryButton
@onready var menu_button: Button = $Panel/VBox/HBox/MenuButton


func _ready() -> void:
	next_button.pressed.connect(func(): next_pressed.emit())
	retry_button.pressed.connect(func(): retry_pressed.emit())
	menu_button.pressed.connect(func(): menu_pressed.emit())
	# Watch the finished attempt again (US-3.1).
	replay_button = Button.new()
	replay_button.text = "Реплей"
	replay_button.custom_minimum_size = retry_button.custom_minimum_size
	replay_button.pressed.connect(func(): replay_pressed.emit())
	retry_button.get_parent().add_child(replay_button)
	visible = false


func show_result(success: bool, saved: int, required: int, total: int, has_next: bool = false) -> void:
	if success:
		title_label.text = "ПОБЕДА!"
		title_label.modulate = Color(0.4, 1.0, 0.4)
	else:
		title_label.text = "ПОРАЖЕНИЕ"
		title_label.modulate = Color(1.0, 0.4, 0.4)
	stats_label.text = "Спасено: %d из %d\nЦель: %d" % [saved, total, required]
	# "Next" only makes sense after a win and when a following level exists.
	next_button.visible = success and has_next
	visible = true
