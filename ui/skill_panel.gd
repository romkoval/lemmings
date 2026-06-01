class_name SkillPanel
extends HBoxContainer

signal skill_selected(skill_name: String)

const SKILL_ORDER: Array[String] = [
	"climber", "floater", "bomber", "blocker",
	"builder", "basher", "miner", "digger",
]
const SKILL_LABELS: Dictionary = {
	"climber": "Клм",
	"floater": "Зон",
	"bomber": "Бмб",
	"blocker": "Блк",
	"builder": "Стр",
	"basher": "Дбл",
	"miner": "Шах",
	"digger": "Коп",
}

var buttons: Dictionary = {}
var selected: String = ""


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	for skill_name in SKILL_ORDER:
		var btn := Button.new()
		btn.set_script(load("res://ui/skill_button.gd"))
		btn.skill_name = skill_name
		btn.text = SKILL_LABELS.get(skill_name, skill_name)
		btn.custom_minimum_size = Vector2(64, 64)
		btn.skill_pressed.connect(_on_skill_pressed)
		add_child(btn)
		buttons[skill_name] = btn


func update_counts(skill_counts: Dictionary) -> void:
	for skill_name in buttons.keys():
		var btn: SkillButton = buttons[skill_name]
		btn.set_count(int(skill_counts.get(skill_name, 0)))


func set_selected(skill_name: String) -> void:
	selected = skill_name
	for name in buttons.keys():
		var btn: SkillButton = buttons[name]
		btn.modulate = Color(1.5, 1.5, 0.6) if name == skill_name else Color.WHITE


func _on_skill_pressed(skill_name: String) -> void:
	skill_selected.emit(skill_name)
