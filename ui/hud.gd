class_name HUD
extends Control

signal pause_pressed()
signal nuke_pressed()
signal skill_chosen(skill_name: String)
signal time_expired()
signal zoom_in_pressed()
signal zoom_out_pressed()

const FAST_SPEED: float = 3.0
# Minimum gap (base px) kept between any control and the screen edge, on top of
# the device safe-area inset — so controls never merge with the phone's bezel,
# notch or rounded corners.
const EDGE_MARGIN: float = 18.0
const TOP_BAR_HEIGHT: float = 56.0
const BOTTOM_BAR_HEIGHT: float = 112.0

@onready var skill_panel: SkillPanel = $BottomBar/SkillPanel
@onready var saved_label: Label = $TopBar/SavedLabel
@onready var spawned_label: Label = $TopBar/SpawnedLabel
@onready var timer_label: Label = $TopBar/TimerLabel
@onready var fast_button: Button = $TopBar/FastButton
@onready var pause_button: Button = $TopBar/PauseButton
@onready var nuke_button: Button = $TopBar/NukeButton
@onready var top_bar: Control = $TopBar
@onready var bottom_bar: Control = $BottomBar
@onready var zoom_controls: Control = $ZoomControls
@onready var zoom_in_button: Button = $ZoomControls/ZoomIn
@onready var zoom_out_button: Button = $ZoomControls/ZoomOut

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
	zoom_in_button.pressed.connect(func(): zoom_in_pressed.emit())
	zoom_out_button.pressed.connect(func(): zoom_out_pressed.emit())
	for zb in [zoom_in_button, zoom_out_button]:
		zb.add_theme_font_size_override("font_size", 30)
	# Keep controls clear of notches / rounded corners, and re-apply if the
	# window is rotated or resized.
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)


# Inset the HUD from the screen edges by the device safe area (notch / home
# indicator) plus a fixed margin, so nothing hugs the bezel. All HUD geometry is
# in the base 720×1280 design space; the OS safe area is in real device pixels,
# so we scale it down by viewport/window before applying.
func _apply_safe_area() -> void:
	var win: Vector2i = DisplayServer.window_get_size()
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var vp: Vector2 = get_viewport_rect().size
	var sx: float = vp.x / float(maxi(1, win.x))
	var sy: float = vp.y / float(maxi(1, win.y))
	# Safe-area insets, scaled into design space. Clamp each to a sane range so a
	# bogus/empty safe area from the OS can never push a panel off-screen.
	var max_x: float = vp.x * 0.25
	var max_y: float = vp.y * 0.25
	var left: float = EDGE_MARGIN + clampf(float(safe.position.x) * sx, 0.0, max_x)
	var top: float = EDGE_MARGIN + clampf(float(safe.position.y) * sy, 0.0, max_y)
	var right: float = EDGE_MARGIN + clampf(float(win.x - safe.end.x) * sx, 0.0, max_x)
	var bottom: float = EDGE_MARGIN + clampf(float(win.y - safe.end.y) * sy, 0.0, max_y)

	top_bar.offset_left = left
	top_bar.offset_right = -right
	top_bar.offset_top = top
	top_bar.offset_bottom = top + TOP_BAR_HEIGHT

	bottom_bar.offset_left = left
	bottom_bar.offset_right = -right
	bottom_bar.offset_bottom = -bottom
	bottom_bar.offset_top = -(bottom + BOTTOM_BAR_HEIGHT)

	# Zoom buttons sit just above the skill panel, against the right inset.
	zoom_controls.offset_right = -right
	zoom_controls.offset_left = -right - 60.0
	zoom_controls.offset_bottom = -(bottom + BOTTOM_BAR_HEIGHT + 10.0)
	zoom_controls.offset_top = zoom_controls.offset_bottom - 128.0


func _process(delta: float) -> void:
	# Only tick the clock while actually playing — so PAUSED simply halts the
	# countdown and resuming continues it (don't clear time_active on pause, or the
	# timer would never restart). time_active stays true until the level resolves.
	if GameManager.current_state == GameManager.GameState.PLAYING and time_active and time_remaining > 0:
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
