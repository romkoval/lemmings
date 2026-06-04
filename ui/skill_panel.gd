class_name SkillPanel
extends HBoxContainer

signal skill_selected(skill_name: String)

const SKILL_ORDER: Array[String] = [
	"climber", "floater", "bomber", "blocker",
	"builder", "basher", "miner", "digger",
]
# Per-skill accent colour — used for the button border + selection glow so each
# action is colour-coded the way the original panel was, while the icon carries
# the meaning.
const SKILL_COLORS: Dictionary = {
	"climber": Color8(0x44, 0x9c, 0xff),
	"floater": Color8(0x9d, 0xd1, 0xff),
	"bomber":  Color8(0xff, 0x55, 0x44),
	"blocker": Color8(0xff, 0xcc, 0x33),
	"builder": Color8(0xff, 0x99, 0x44),
	"basher":  Color8(0xc0, 0x60, 0xff),
	"miner":   Color8(0xc8, 0x90, 0x50),
	"digger":  Color8(0x44, 0xc8, 0x66),
}
const PANEL_BG := Color8(0x24, 0x22, 0x30)

var buttons: Dictionary = {}
var selected: String = ""


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	# Centre the row so the inset bottom bar keeps the buttons clear of the edges.
	alignment = BoxContainer.ALIGNMENT_CENTER
	for skill_name in SKILL_ORDER:
		var btn := Button.new()
		btn.set_script(load("res://ui/skill_button.gd"))
		btn.skill_name = skill_name
		btn.custom_minimum_size = Vector2(72, 80)
		# Pixel-art icon — keep it crisp (no smoothing) and let it fill the button.
		var icon_path := "res://assets/sprites/skill_%s.png" % skill_name
		if ResourceLoader.exists(icon_path):
			var tex := load(icon_path) as Texture2D
			btn.icon = tex
			btn.expand_icon = true
			btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			btn.add_theme_constant_override("icon_max_width", 56)
		var tint: Color = SKILL_COLORS.get(skill_name, Color.WHITE)
		var sb := StyleBoxFlat.new()
		sb.bg_color = PANEL_BG
		sb.border_color = tint
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(5)
		sb.content_margin_top = 6
		btn.add_theme_stylebox_override("normal", sb)
		var sb_hover := sb.duplicate() as StyleBoxFlat
		sb_hover.bg_color = PANEL_BG.lightened(0.12)
		btn.add_theme_stylebox_override("hover", sb_hover)
		var sb_pressed := sb.duplicate() as StyleBoxFlat
		sb_pressed.bg_color = tint.darkened(0.55)
		btn.add_theme_stylebox_override("pressed", sb_pressed)
		var sb_disabled := sb.duplicate() as StyleBoxFlat
		sb_disabled.border_color = tint.darkened(0.6)
		btn.add_theme_stylebox_override("disabled", sb_disabled)
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
		btn.modulate = Color(1.7, 1.7, 1.7) if name == skill_name else Color.WHITE


func _on_skill_pressed(skill_name: String) -> void:
	skill_selected.emit(skill_name)
