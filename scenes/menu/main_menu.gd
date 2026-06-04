extends Control

# Animated main menu. Static layout lives in main_menu.tscn; this script adds
# the life: a row of lemmings marching across the ground, a title that drops in
# and gently pulses, buttons that slide in on load, and a mute toggle.

const LEMMING_FRAMES: SpriteFrames = preload("res://entities/lemming_frames.tres")
const MARCH_COUNT: int = 6
const MARCH_SPEED: float = 70.0
const LEMMING_SCALE: float = 4.0

@onready var title: Label = $Title
@onready var buttons: VBoxContainer = $Buttons
@onready var play_button: Button = $Buttons/PlayButton
@onready var level_select_button: Button = $Buttons/LevelSelectButton
@onready var settings_button: Button = $Buttons/SettingsButton
@onready var quit_button: Button = $Buttons/QuitButton
@onready var mute_button: Button = $MuteButton
@onready var lemming_layer: Node2D = $LemmingLayer
@onready var ground: ColorRect = $Ground

var _marchers: Array[AnimatedSprite2D] = []
var _ground_y: float = 0.0


func _ready() -> void:
	play_button.pressed.connect(_on_play)
	level_select_button.pressed.connect(_on_select)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)
	mute_button.pressed.connect(_on_mute)
	_style_buttons()
	_refresh_mute()
	_spawn_marchers()
	_animate_intro()
	# Make sure menu music is playing (e.g. when returning from a level).
	if not AudioManager.music_player.playing:
		AudioManager.play_music("theme")


# ── Marching lemmings ──────────────────────────────────────────────────────
func _spawn_marchers() -> void:
	_ground_y = ground.position.y
	var spacing: float = size.x / float(MARCH_COUNT)
	for i in MARCH_COUNT:
		var lem := AnimatedSprite2D.new()
		lem.sprite_frames = LEMMING_FRAMES
		lem.animation = &"walk"
		lem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		lem.scale = Vector2(LEMMING_SCALE, LEMMING_SCALE)
		lem.position = Vector2(spacing * i + 40.0, _ground_y - 28.0)
		lem.play()
		lemming_layer.add_child(lem)
		_marchers.append(lem)


func _process(delta: float) -> void:
	for lem in _marchers:
		lem.position.x += MARCH_SPEED * delta
		if lem.position.x > size.x + 40.0:
			lem.position.x = -40.0


# ── Intro animation ────────────────────────────────────────────────────────
func _animate_intro() -> void:
	# Title drops in from above, then breathes.
	var final_y: float = title.position.y
	title.position.y = final_y - 120.0
	title.modulate.a = 0.0
	var t := create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(title, "position:y", final_y, 0.6)
	t.parallel().tween_property(title, "modulate:a", 1.0, 0.5)
	t.tween_callback(_start_title_pulse)
	# Slide the whole button group up (it's a Container, so per-child positions
	# can't be tweened — but their modulate can, giving a staggered fade-in).
	var group_y: float = buttons.position.y
	buttons.position.y = group_y + 50.0
	var gt := create_tween()
	gt.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	gt.tween_property(buttons, "position:y", group_y, 0.45)
	var children := buttons.get_children()
	for i in children.size():
		var btn := children[i] as Control
		btn.modulate.a = 0.0
		var bt := create_tween()
		bt.tween_interval(0.3 + 0.08 * i)
		bt.tween_property(btn, "modulate:a", 1.0, 0.3)


func _start_title_pulse() -> void:
	# Set the pivot now that layout has settled, so the pulse scales about centre.
	title.pivot_offset = title.size * 0.5
	var base: float = title.scale.x
	var pulse := create_tween().set_loops()
	pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(title, "scale", Vector2(base * 1.04, base * 1.04), 1.4)
	pulse.tween_property(title, "scale", Vector2(base, base), 1.4)


# ── Styling ────────────────────────────────────────────────────────────────
func _style_buttons() -> void:
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	title.add_theme_constant_override("outline_size", 10)
	var accents := {
		play_button: Color(0.3, 0.78, 0.4),
		level_select_button: Color(0.32, 0.6, 1.0),
		settings_button: Color(0.7, 0.55, 1.0),
		quit_button: Color(0.9, 0.4, 0.4),
	}
	for btn in accents.keys():
		_style_button(btn, accents[btn])


func _style_button(btn: Button, accent: Color) -> void:
	btn.add_theme_font_size_override("font_size", 34)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.13, 0.18) if state != "hover" else Color(0.2, 0.19, 0.26)
		if state == "pressed":
			sb.bg_color = accent.darkened(0.5)
		sb.border_color = accent
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(14)
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", Color.WHITE)


# ── Mute ───────────────────────────────────────────────────────────────────
func _on_mute() -> void:
	AudioManager.toggle_mute()
	SaveManager.save_progress()
	_refresh_mute()


func _refresh_mute() -> void:
	var muted: bool = AudioManager.is_muted()
	mute_button.text = "Звук: выкл" if muted else "Звук: вкл"
	mute_button.modulate = Color(0.75, 0.55, 0.55) if muted else Color(1, 1, 1)


# ── Navigation ─────────────────────────────────────────────────────────────
func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _on_select() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/level_select.tscn")


func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/settings.tscn")


func _on_quit() -> void:
	get_tree().quit()
