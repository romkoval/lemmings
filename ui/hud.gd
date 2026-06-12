class_name HUD
extends Control

signal pause_pressed()
signal step_pressed()
signal nuke_pressed()
signal skill_chosen(skill_name: String)
signal time_expired()
signal zoom_in_pressed()
signal zoom_out_pressed()
signal release_rate_changed(rate: int)

const FAST_SPEED: float = 3.0
# Release-rate control: can never drop below the level's starting rate (the
# classic rule — the author's minimum is part of the puzzle), capped at 99.
const RATE_MAX: int = 99
# Hold-to-repeat for the −/+ buttons: first repeat after the delay, then a
# steady stream — riffling across the whole range takes about two seconds.
const RATE_REPEAT_DELAY: float = 0.35
const RATE_REPEAT_INTERVAL: float = 0.05
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
@onready var step_button: Button = $TopBar/StepButton
@onready var nuke_button: Button = $TopBar/NukeButton
@onready var top_bar: Control = $TopBar
@onready var bottom_bar: Control = $BottomBar
@onready var zoom_controls: Control = $ZoomControls
@onready var zoom_in_button: Button = $ZoomControls/ZoomIn
@onready var zoom_out_button: Button = $ZoomControls/ZoomOut
@onready var minimap: Control = $Minimap
@onready var release_controls: Control = $ReleaseControls
@onready var rate_plus_button: Button = $ReleaseControls/RatePlus
@onready var rate_minus_button: Button = $ReleaseControls/RateMinus
@onready var rate_label: Label = $ReleaseControls/RateLabel

var time_remaining: float = 0.0
var time_active: bool = false
var required_saved: int = 0
var release_rate: int = 50
var min_release_rate: int = 1
var _rate_hold_dir: int = 0
var _rate_hold_time: float = 0.0
# Current safe-area insets in design px (left, top, right, bottom) — what
# _apply_safe_area last computed. Other HUD-anchored UI (the hint banner)
# positions itself off these via hint_rect().
var _insets := Vector4(EDGE_MARGIN, EDGE_MARGIN, EDGE_MARGIN, EDGE_MARGIN)


func _ready() -> void:
	pause_button.pressed.connect(func(): pause_pressed.emit())
	step_button.pressed.connect(func(): step_pressed.emit())
	nuke_button.pressed.connect(func(): nuke_pressed.emit())
	fast_button.toggled.connect(_on_fast_toggled)
	# time_scale / tick rate are global state — never leak back to the menus.
	tree_exiting.connect(func(): _set_speed(1.0))
	skill_panel.skill_selected.connect(func(name: String): skill_chosen.emit(name))
	rate_plus_button.button_down.connect(func(): _on_rate_button_down(1))
	rate_minus_button.button_down.connect(func(): _on_rate_button_down(-1))
	for rb in [rate_plus_button, rate_minus_button]:
		rb.button_up.connect(func(): _rate_hold_dir = 0)
		rb.add_theme_font_size_override("font_size", 30)
	for label in [saved_label, spawned_label, timer_label, rate_label]:
		if label:
			label.add_theme_font_size_override("font_size", 20)
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 3)
	for btn in [pause_button, nuke_button, step_button]:
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
	_apply_insets(left, top, right, bottom)


# Lay the HUD out for the given insets (margin already included). Split from
# _apply_safe_area so tests can drive it with notch-sized values that the OS
# won't report on a desktop.
func _apply_insets(left: float, top: float, right: float, bottom: float) -> void:
	_insets = Vector4(left, top, right, bottom)

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

	# Release-rate −/+ mirrors the zoom column on the left inset.
	release_controls.offset_left = left
	release_controls.offset_right = left + 56.0
	release_controls.offset_bottom = -(bottom + BOTTOM_BAR_HEIGHT + 10.0)
	release_controls.offset_top = release_controls.offset_bottom - 152.0

	# Minimap: top-right, just under the top bar (size set once a level is bound).
	if minimap:
		minimap.offset_right = -right
		minimap.offset_left = -right - minimap.size.x
		minimap.offset_top = top + TOP_BAR_HEIGHT + 10.0
		minimap.offset_bottom = minimap.offset_top + minimap.size.y


# Wire the minimap to the current level + camera; called by Game on level load.
func bind_minimap(level: Node, camera: Node) -> void:
	if minimap and minimap.has_method("bind"):
		minimap.bind(level, camera)
		_apply_safe_area()


# Where a transient banner (the level hint) may sit: under the top bar inside
# the safe-area insets, stopping short of the minimap — so it can never cover
# the camera cutout, the counters or the corner controls. Height is 0: the
# banner grows downward from here.
func hint_rect() -> Rect2:
	var left: float = _insets.x
	var top: float = _insets.y + TOP_BAR_HEIGHT + 8.0
	var right_edge: float = size.x - _insets.z
	if minimap and minimap.visible:
		right_edge = size.x + minimap.offset_left - 10.0
	return Rect2(left, top, maxf(160.0, right_edge - left), 0.0)


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
	# Framestep is only meaningful while paused.
	if step_button:
		step_button.disabled = GameManager.current_state != GameManager.GameState.PAUSED
	if _rate_hold_dir != 0:
		# Held −/+ keeps stepping: first repeat after the delay, then one step
		# per interval (the while-loop catches up after a slow frame).
		_rate_hold_time += delta
		while _rate_hold_time >= RATE_REPEAT_DELAY + RATE_REPEAT_INTERVAL:
			_rate_hold_time -= RATE_REPEAT_INTERVAL
			_change_rate(_rate_hold_dir)
	_update_labels()


func configure(total_lemmings: int, required: int, time_limit_sec: int, skill_counts: Dictionary, start_release_rate: int = 50) -> void:
	required_saved = required
	time_remaining = float(time_limit_sec)
	time_active = true
	min_release_rate = clampi(start_release_rate, 1, RATE_MAX)
	release_rate = min_release_rate
	_rate_hold_dir = 0
	skill_panel.update_counts(skill_counts)
	_update_labels()


func _on_rate_button_down(dir: int) -> void:
	_change_rate(dir)
	_rate_hold_dir = dir
	_rate_hold_time = 0.0


func _change_rate(delta_steps: int) -> void:
	var new_rate: int = clampi(release_rate + delta_steps, min_release_rate, RATE_MAX)
	if new_rate == release_rate:
		return
	release_rate = new_rate
	release_rate_changed.emit(release_rate)


func _on_fast_toggled(on: bool) -> void:
	_set_speed(FAST_SPEED if on else 1.0)
	fast_button.text = "»»" if on else "»"


func _set_speed(factor: float) -> void:
	# time_scale alone is not enough: in Godot 4 it scales the clock and deltas
	# but does NOT add physics ticks, and the lemmings move in whole pixels per
	# physics tick. Raise the tick rate with it so fast-forward actually runs
	# the simulation faster (each tick still sees delta = 1/60 of game time).
	Engine.time_scale = factor
	Engine.physics_ticks_per_second = int(60.0 * factor)


func update_skill_counts(skill_counts: Dictionary) -> void:
	skill_panel.update_counts(skill_counts)


func mark_selected_skill(skill_name: String) -> void:
	skill_panel.set_selected(skill_name)


func _update_labels() -> void:
	if saved_label:
		saved_label.text = tr("Спасено: %d / %d") % [GameManager.saved_count, required_saved]
	if spawned_label:
		spawned_label.text = tr("Вышло: %d") % GameManager.spawned_count
	if timer_label:
		var m: int = int(time_remaining) / 60
		var s: int = int(time_remaining) % 60
		timer_label.text = "%02d:%02d" % [m, s]
	if rate_label:
		rate_label.text = str(release_rate)
