class_name SkillButton
extends Button

signal skill_pressed(skill_name: String)

@export var skill_name: String = ""

var count_label: Label = null
var _current_count: int = 0


func _ready() -> void:
	count_label = Label.new()
	count_label.text = "0"
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.position = Vector2(2, 2)
	add_child(count_label)
	pressed.connect(_on_pressed)


func set_count(count: int) -> void:
	_current_count = count
	if count_label:
		count_label.text = str(count)
	disabled = count <= 0


func get_count() -> int:
	return _current_count


func _on_pressed() -> void:
	skill_pressed.emit(skill_name)
