class_name HUD
extends Control

signal pause_pressed()
signal nuke_pressed()
signal skill_chosen(skill_name: String)
signal time_expired()

const FAST_SPEED: float = 3.0

@onready var skill_panel: SkillPanel = $BottomBar/SkillPanel
@onready var saved_label: Label = $TopBar/SavedLabel
@onready var spawned_label: Label = $TopBar/SpawnedLabel
@onready var timer_label: Label = $TopBar/TimerLabel
@onready var fast_button: Button = $TopBar/FastButton
@onready var pause_button: Button = $TopBar/PauseButton
@onready var nuke_button: Button = $TopBar/NukeButton

var time_remaining: float = 0.0
var time_active: bool = false
var required_saved: int = 0


func _ready() -> void:
	pause_button.pressed.connect(func(): pause_pressed.emit())
	nuke_button.pressed.connect(func(): nuke_pressed.emit())
	fast_button.toggled.connect(_on_fast_toggled)
	# time_scale is global state — make sure it doesn't leak back to the menus.
	tree_exiting.connect(func(): Engine.time_scale = 1.0)
	skill_panel.skill_selected.connect(func(name: String): skill_chosen.emit(name))
	for label in [saved_label, spawned_label, timer_label]:
		if label:
			label.add_theme_font_size_override("font_size", 22)
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 3)
	for btn in [pause_button, nuke_button]:
		if btn:
			btn.add_theme_font_size_override("font_size", 18)


func _process(delta: float) -> void:
	# Stop the clock once the level is no longer being played.
	if GameManager.current_state != GameManager.GameState.PLAYING:
		time_active = false
	if time_active and time_remaining > 0:
		time_remaining -= delta
		if time_remaining <= 0:
			time_remaining = 0
			time_active = false
			time_expired.emit()
	_update_labels()


func configure(total_lemmings: int, required: int, time_limit_sec: int, skill_counts: Dictionary) -> void:
	required_saved = required
	time_remaining = float(time_limit_sec)
	time_active = true
	skill_panel.update_counts(skill_counts)
	_update_labels()


func _on_fast_toggled(on: bool) -> void:
	Engine.time_scale = FAST_SPEED if on else 1.0
	fast_button.text = "»»" if on else "»"


func update_skill_counts(skill_counts: Dictionary) -> void:
	skill_panel.update_counts(skill_counts)


func mark_selected_skill(skill_name: String) -> void:
	skill_panel.set_selected(skill_name)


func _update_labels() -> void:
	if saved_label:
		saved_label.text = "Спасено: %d / %d" % [GameManager.saved_count, required_saved]
	if spawned_label:
		spawned_label.text = "Вышло: %d" % GameManager.spawned_count
	if timer_label:
		var m: int = int(time_remaining) / 60
		var s: int = int(time_remaining) % 60
		timer_label.text = "%02d:%02d" % [m, s]
