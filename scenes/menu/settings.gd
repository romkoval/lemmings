extends Control

# Settings screen: music & SFX volume, plus a global mute. Changes apply live
# (you hear them immediately) and persist via SaveManager on exit.

@onready var music_slider: HSlider = $Panel/VBox/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $Panel/VBox/SfxRow/SfxSlider
@onready var mute_check: CheckButton = $Panel/VBox/MuteRow/MuteCheck
@onready var music_value: Label = $Panel/VBox/MusicRow/MusicValue
@onready var sfx_value: Label = $Panel/VBox/SfxRow/SfxValue
@onready var back_button: Button = $Panel/VBox/BackButton


func _ready() -> void:
	music_slider.value = float(SaveManager.settings.get("music_volume", 0.8))
	sfx_slider.value = float(SaveManager.settings.get("sfx_volume", 1.0))
	mute_check.button_pressed = AudioManager.is_muted()
	_update_labels()
	_update_enabled()

	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	sfx_slider.drag_ended.connect(_on_sfx_drag_ended)
	mute_check.toggled.connect(_on_mute_toggled)
	back_button.pressed.connect(_on_back)
	_build_stats_block()


# Lifetime statistics (US-3.4), shown under the audio settings.
const CAUSE_LABELS: Dictionary = {
	"splat": "Разбились", "drowned": "Утонули", "burned": "Сгорели",
	"trapped": "В ловушках", "bomb": "Взорвались", "fell_out": "Пропали в бездне",
}


func _build_stats_block() -> void:
	var box: VBoxContainer = back_button.get_parent()
	var header := Label.new()
	header.text = "Статистика"
	header.add_theme_font_size_override("font_size", 26)
	box.add_child(header)
	box.move_child(header, back_button.get_index())
	var s: Dictionary = SaveManager.stats
	var lines: Array = [
		"Уровней пройдено: %d из %d сыгранных" % [int(s.get("levels_won", 0)), int(s.get("levels_played", 0))],
		"Спасено леммингов: %d" % int(s.get("saved", 0)),
		"Погибло леммингов: %d" % int(s.get("dead", 0)),
	]
	var by_cause: Dictionary = s.get("by_cause", {})
	for cause in CAUSE_LABELS:
		if int(by_cause.get(cause, 0)) > 0:
			lines.append("  %s: %d" % [CAUSE_LABELS[cause], int(by_cause[cause])])
	for line in lines:
		var lbl := Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 20)
		box.add_child(lbl)
		box.move_child(lbl, back_button.get_index())


func _on_music_changed(v: float) -> void:
	AudioManager.set_music_volume(v)
	_update_labels()


func _on_sfx_changed(v: float) -> void:
	AudioManager.set_sfx_volume(v)
	_update_labels()


# Preview the SFX volume by playing a click when the user lets go of the slider.
func _on_sfx_drag_ended(_changed: bool) -> void:
	AudioManager.play_sfx("skill_assign")


func _on_mute_toggled(pressed: bool) -> void:
	AudioManager.set_muted(pressed)
	_update_enabled()


func _update_labels() -> void:
	music_value.text = "%d%%" % roundi(music_slider.value * 100.0)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value * 100.0)


func _update_enabled() -> void:
	var on: bool = not mute_check.button_pressed
	music_slider.editable = on
	sfx_slider.editable = on


func _on_back() -> void:
	SaveManager.save_progress()
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
