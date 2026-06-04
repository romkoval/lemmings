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
