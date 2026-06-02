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
# Distinct vivid background tint per skill — gives the HUD pixel-art icon feel.
const SKILL_COLORS: Dictionary = {
	"climber": Color8(0x44, 0x9c, 0xff),
	"floater": Color8(0x9d, 0xd1, 0xff),
	"bomber":  Color8(0xff, 0x55, 0x44),
	"blocker": Color8(0xff, 0xcc, 0x33),
	"builder": Color8(0xff, 0x99, 0x44),
	"basher":  Color8(0xc0, 0x60, 0xff),
	"miner":   Color8(0xa0, 0x70, 0x40),
	"digger":  Color8(0x44, 0xc8, 0x66),
}

var buttons: Dictionary = {}
var selected: String = ""


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	for skill_name in SKILL_ORDER:
		var btn := Button.new()
		btn.set_script(load("res://ui/skill_button.gd"))
		btn.skill_name = skill_name
		btn.text = SKILL_LABELS.get(skill_name, skill_name)
		btn.custom_minimum_size = Vector2(72, 80)
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", Color.BLACK)
		var tint: Color = SKILL_COLORS.get(skill_name, Color.WHITE)
		var sb := StyleBoxFlat.new()
		sb.bg_color = tint
		sb.border_color = Color.BLACK
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", sb)
		var sb_hover := sb.duplicate() as StyleBoxFlat
		sb_hover.bg_color = tint.lightened(0.15)
		btn.add_theme_stylebox_override("hover", sb_hover)
		var sb_pressed := sb.duplicate() as StyleBoxFlat
		sb_pressed.bg_color = tint.darkened(0.2)
		btn.add_theme_stylebox_override("pressed", sb_pressed)
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
