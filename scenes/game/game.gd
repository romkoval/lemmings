class_name Game
extends Node2D

const HUD_SCENE: PackedScene = preload("res://ui/hud.tscn")
const RESULT_SCENE: PackedScene = preload("res://ui/result_screen.tscn")
# Preloaded as a type (not via class_name) so the game scene doesn't depend on
# the global script-class cache — see camera_controller.gd.
const GameCameraScript = preload("res://scenes/game/camera_controller.gd")

@export var initial_level_path: String = ""

@onready var level_container: Node2D = $LevelContainer
@onready var hud_layer: CanvasLayer = $HUDLayer
@onready var camera: GameCameraScript = $Camera2D

# How far (screen px) a single finger may move before it counts as a drag rather
# than a tap — past this, releasing it won't assign a skill.
const TAP_SLOP: float = 16.0

# Active touch points, keyed by finger index → last known screen position. Used
# to tell a one-finger tap (assign skill) from a two-finger gesture (pan/zoom).
var _touches: Dictionary = {}
var _gesture_active: bool = false   # ≥2 fingers were down during this interaction
var _press_pos: Vector2 = Vector2.ZERO
var _press_moved: bool = false
var _pinch_start_dist: float = 0.0
var _pinch_start_zoom: float = 1.0
var _pan_last_centroid: Vector2 = Vector2.ZERO
var _mouse_panning: bool = false

var current_level: Level = null
var current_level_path: String = ""
# Replays (US-3.1): every player action is logged against GameManager.sim_tick;
# playback re-applies the log on the exact same ticks. The pixel simulation is
# fully deterministic (fixed tick, integer pixels), so outcomes reproduce.
var replay_log: Array = []
var last_replay: Array = []
var replay_mode: bool = false
var _replay_queue: Array = []
var lemming_manager: LemmingManager = null
var skill_manager: SkillManager = null
var hud: HUD = null
var result_screen: ResultScreen = null
var _highlighted: Lemming = null


func _ready() -> void:
	lemming_manager = LemmingManager.new()
	lemming_manager.name = "LemmingManager"
	add_child(lemming_manager)
	skill_manager = SkillManager.new()
	skill_manager.name = "SkillManager"
	add_child(skill_manager)

	hud = HUD_SCENE.instantiate()
	hud_layer.add_child(hud)
	hud.pause_pressed.connect(_on_pause)
	hud.step_pressed.connect(func(): GameManager.framestep())
	hud.nuke_pressed.connect(_on_nuke)
	hud.skill_chosen.connect(_on_skill_chosen)
	hud.zoom_in_pressed.connect(func(): camera.zoom_in())
	hud.zoom_out_pressed.connect(func(): camera.zoom_out())
	hud.release_rate_changed.connect(_on_release_rate_changed)
	skill_manager.skill_count_changed.connect(_on_skill_count_changed)
	skill_manager.skill_assigned.connect(_on_skill_assigned_record)
	hud.time_expired.connect(_on_time_expired)
	GameManager.all_lemmings_resolved.connect(_on_all_resolved)

	result_screen = RESULT_SCENE.instantiate()
	hud_layer.add_child(result_screen)
	result_screen.retry_pressed.connect(_on_retry)
	result_screen.menu_pressed.connect(_on_back_to_menu)
	result_screen.next_pressed.connect(_on_next)
	result_screen.replay_pressed.connect(_on_replay)
	GameManager.level_completed.connect(_on_level_completed)
	GameManager.level_failed.connect(_on_level_failed)

	var path: String = initial_level_path
	if path == "":
		path = "res://levels/fun/level_01.tscn"
	if ResourceLoader.exists(path):
		load_level(path)


# Accepts either a level scene (.tscn) or a custom-level .json saved by the
# in-game editor — the latter is played through the shared custom_base scene
# with its data_path pointed at the JSON. Pass a replay log to WATCH the
# attempt instead of playing it.
func load_level(scene_path: String, replay: Array = []) -> void:
	replay_mode = not replay.is_empty()
	_replay_queue = replay.duplicate(true)
	replay_log = []
	_load_level_scene(scene_path)


func _load_level_scene(scene_path: String) -> void:
	if current_level:
		current_level.queue_free()
	var new_level: Level = null
	if scene_path.ends_with(".json"):
		var base: PackedScene = load("res://levels/custom_base.tscn")
		new_level = base.instantiate() as Level
		new_level.set("data_path", scene_path)
	else:
		var scene: PackedScene = load(scene_path)
		if scene == null:
			return
		new_level = scene.instantiate() as Level
	if new_level == null:
		return
	if result_screen:
		result_screen.visible = false
	current_level_path = scene_path
	current_level = new_level
	level_container.add_child(current_level)
	skill_manager.configure(current_level.skill_counts)
	hud.configure(
		current_level.total_lemmings,
		current_level.save_required,
		current_level.time_limit,
		skill_manager.skill_counts,
		current_level.release_rate,
	)
	GameManager.start_level(current_level.level_id, current_level.total_lemmings)
	# Frame the camera on the level: clamp panning to the terrain and centre on
	# the entrance so the first lemmings are visible immediately.
	if camera:
		var focus: Vector2 = current_level.entrance.global_position if current_level.entrance else Vector2.INF
		camera.setup_bounds(current_level, focus)
	hud.bind_minimap(current_level, camera)
	# Each level gets its own tune from the remake pack (restart keeps it going).
	AudioManager.play_level_music(current_level.level_id)
	_show_hint(current_level.hint)


# Onboarding (US-5.2): a one-time dismissible tip over the HUD. Per-level,
# remembered in the save; the settings screen can turn hints off entirely.
var _hint_panel: PanelContainer = null


func _show_hint(text: String) -> void:
	if _hint_panel != null:
		_hint_panel.queue_free()
		_hint_panel = null
	if text == "" or replay_mode:
		return
	if not bool(SaveManager.settings.get("hints_enabled", true)):
		return
	var shown: Dictionary = SaveManager.settings.get("hints_shown", {})
	if bool(shown.get(GameManager.current_level_id, false)):
		return
	_hint_panel = PanelContainer.new()
	# Below the top bar and inside the safe-area insets (notch, rounded corners),
	# clear of the minimap — the HUD owns that geometry.
	var slot: Rect2 = hud.hint_rect()
	_hint_panel.offset_left = slot.position.x
	_hint_panel.offset_right = slot.end.x
	_hint_panel.offset_top = slot.position.y
	hud_layer.add_child(_hint_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_hint_panel.add_child(box)
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 21)
	box.add_child(lbl)
	var ok := Button.new()
	ok.text = "Понятно"
	ok.custom_minimum_size = Vector2(0, 48)
	ok.pressed.connect(_dismiss_hint)
	box.add_child(ok)


func _dismiss_hint() -> void:
	if _hint_panel != null:
		_hint_panel.queue_free()
		_hint_panel = null
	var shown: Dictionary = SaveManager.settings.get("hints_shown", {})
	shown[GameManager.current_level_id] = true
	SaveManager.settings["hints_shown"] = shown
	SaveManager.save_progress()


func _physics_process(_delta: float) -> void:
	# Replay playback: apply every logged event whose tick has arrived.
	if not replay_mode or not _playing():
		return
	while not _replay_queue.is_empty() and int(_replay_queue[0].get("t", 0)) <= GameManager.sim_tick:
		_apply_replay_event(_replay_queue.pop_front())


func _apply_replay_event(e: Dictionary) -> void:
	match str(e.get("type", "")):
		"assign":
			var id: int = int(e.get("id", -1))
			for n in get_tree().get_nodes_in_group("lemmings"):
				var lem := n as Lemming
				if lem != null and lem.lemming_id == id:
					if skill_manager.select_skill(str(e.get("skill", ""))):
						skill_manager.assign_to(lem)
					break
		"rate":
			if current_level and current_level.entrance:
				current_level.entrance.set_release_rate(int(e.get("v", 50)))
		"nuke":
			lemming_manager.nuke_all()


func _record(e: Dictionary) -> void:
	if not replay_mode:
		e["t"] = GameManager.sim_tick
		replay_log.append(e)


func _on_skill_assigned_record(skill_name: String, lemming: Lemming) -> void:
	_record({"type": "assign", "skill": skill_name, "id": lemming.lemming_id})


func _unhandled_input(event: InputEvent) -> void:
	# _unhandled_input (not _input) so taps on HUD buttons and the minimap are
	# consumed by those controls first and never reach gameplay. Camera gestures
	# work in any state; skill assignment only while playing.
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _mouse_panning:
			camera.pan_screen(mm.relative)
		elif _playing():
			_update_highlight(get_global_mouse_position())


func _playing() -> bool:
	return GameManager.current_state == GameManager.GameState.PLAYING


# ── Touch: one finger = aim/assign, two fingers = pan + pinch-zoom ──────────
func _handle_touch(st: InputEventScreenTouch) -> void:
	if st.pressed:
		_touches[st.index] = st.position
		if _touches.size() == 1:
			_press_pos = st.position
			_press_moved = false
			_gesture_active = false
			if _playing():
				_update_highlight(_screen_to_world(st.position))
		elif _touches.size() == 2:
			_gesture_active = true
			_set_highlight(null)
			_begin_pinch()
	else:
		_touches.erase(st.index)
		if _touches.is_empty():
			# Interaction ended: a clean single-finger tap assigns the skill.
			if _playing() and not _gesture_active and not _press_moved:
				_try_assign_at(_screen_to_world(st.position))
			_set_highlight(null)
			_gesture_active = false
		elif _touches.size() == 1:
			# Dropped from two fingers to one — re-seat the pan anchor so the
			# remaining finger doesn't cause a jump.
			_pan_last_centroid = _touches.values()[0]


func _handle_drag(sd: InputEventScreenDrag) -> void:
	_touches[sd.index] = sd.position
	if _touches.size() >= 2:
		_update_pinch()
	else:
		# One finger past the tap threshold = pan the scene (no longer eligible to
		# assign a skill). Below the threshold it's still a potential tap.
		if not _press_moved and sd.position.distance_to(_press_pos) > TAP_SLOP:
			_press_moved = true
			_set_highlight(null)
		if _press_moved:
			camera.pan_screen(sd.relative)
		elif _playing():
			_update_highlight(_screen_to_world(sd.position))


func _begin_pinch() -> void:
	var pts: Array = _touches.values()
	_pinch_start_dist = maxf(1.0, pts[0].distance_to(pts[1]))
	_pinch_start_zoom = camera.zoom.x
	_pan_last_centroid = (pts[0] + pts[1]) * 0.5


func _update_pinch() -> void:
	var pts: Array = _touches.values()
	var dist: float = maxf(1.0, pts[0].distance_to(pts[1]))
	var centroid: Vector2 = (pts[0] + pts[1]) * 0.5
	camera.set_zoom_level(_pinch_start_zoom * (dist / _pinch_start_dist))
	camera.pan_screen(centroid - _pan_last_centroid)
	_pan_last_centroid = centroid


# ── Desktop: wheel zooms, right-drag pans ──────────────────────────────────
func _handle_mouse_button(mb: InputEventMouseButton) -> void:
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if mb.pressed:
				camera.zoom_in()
		MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				camera.zoom_out()
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			_mouse_panning = mb.pressed
			if _mouse_panning:
				_set_highlight(null)


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


func _try_assign_at(world_pos: Vector2) -> void:
	if replay_mode:
		return   # watching, not playing
	if skill_manager.selected_skill == "":
		return
	var nearest: Lemming = _find_lemming_near(world_pos, 24.0)
	if nearest == null:
		return
	skill_manager.assign_to(nearest)


# Highlight the lemming that a tap near `world_pos` would target, so the player
# can see who is about to get the selected skill (touch is imprecise).
func _update_highlight(world_pos: Vector2) -> void:
	if skill_manager.selected_skill == "":
		_set_highlight(null)
		return
	_set_highlight(_find_lemming_near(world_pos, 28.0))


func _set_highlight(lem: Lemming) -> void:
	if lem == _highlighted:
		return
	if _highlighted != null and is_instance_valid(_highlighted):
		_highlighted.set_highlighted(false)
	_highlighted = lem
	if _highlighted != null:
		_highlighted.set_highlighted(true)


func _find_lemming_near(pos: Vector2, max_dist: float) -> Lemming:
	# Crowd-aware pick (US-1.2): eligibility for the selected skill, walkers
	# before workers, direction toward the tap — see SkillManager.pick_target.
	return skill_manager.pick_target(get_tree().get_nodes_in_group("lemmings"), pos, max_dist)


func _on_skill_chosen(skill_name: String) -> void:
	if skill_manager.select_skill(skill_name):
		hud.mark_selected_skill(skill_name)


func _on_skill_count_changed(_skill_name: String, _count: int) -> void:
	hud.update_skill_counts(skill_manager.skill_counts)


func _on_pause() -> void:
	if GameManager.current_state == GameManager.GameState.PLAYING:
		GameManager.set_state(GameManager.GameState.PAUSED)
	else:
		GameManager.set_state(GameManager.GameState.PLAYING)


func _on_nuke() -> void:
	_record({"type": "nuke"})
	lemming_manager.nuke_all()


func _on_release_rate_changed(rate: int) -> void:
	_record({"type": "rate", "v": rate})
	if current_level and current_level.entrance:
		current_level.entrance.set_release_rate(rate)


func _on_all_resolved() -> void:
	GameManager.complete_level(current_level.save_required)


func _on_time_expired() -> void:
	if GameManager.current_state == GameManager.GameState.PLAYING:
		GameManager.complete_level(current_level.save_required)


func _on_level_completed(saved: int, required: int) -> void:
	SaveManager.record_result(GameManager.current_level_id, saved,
		current_level.total_lemmings, int(hud.time_remaining))
	_finish_replay_log()
	# US-4.2: winning a test-play from the editor proves the level is solvable —
	# stamp it verified; the recorded attempt is the author's proof replay.
	if not replay_mode and LevelManager.editing_path != "":
		var d: Dictionary = LevelManager.load_level_json(LevelManager.editing_path)
		if not d.is_empty():
			d["verified"] = true
			LevelManager.save_level_json(LevelManager.editing_path, d)
	result_screen.show_result(true, saved, required, current_level.total_lemmings, _next_level_path() != "")


# Resolves the scene path of the level following the current one, or "" if the
# current level is the last in its category. Derives category + number from the
# level id (e.g. "fun_03" -> fun / 3 -> next is fun / 4).
func _next_level_path() -> String:
	if current_level == null:
		return ""
	var id: String = current_level.level_id
	var sep: int = id.rfind("_")
	if sep <= 0:
		return ""
	var category: String = id.substr(0, sep)
	var number: int = id.substr(sep + 1).to_int()
	if number <= 0:
		return ""
	var next_path: String = LevelManager.get_scene_path(category, number + 1)
	return next_path if ResourceLoader.exists(next_path) else ""


func _on_next() -> void:
	var next_path: String = _next_level_path()
	if next_path == "":
		_on_back_to_menu()
		return
	load_level(next_path)


func _on_level_failed(_reason: String) -> void:
	# A lost attempt still records its best (e.g. saved some but missed quota).
	SaveManager.record_result(GameManager.current_level_id, GameManager.saved_count,
		current_level.total_lemmings, int(hud.time_remaining))
	_finish_replay_log()
	result_screen.show_result(false, GameManager.saved_count, current_level.save_required, current_level.total_lemmings)


# Keep the attempt's log (for the result-screen replay button) and persist it.
# A watched replay never overwrites the recording it came from.
func _finish_replay_log() -> void:
	if replay_mode:
		return
	last_replay = replay_log.duplicate(true)
	LevelManager.save_replay(GameManager.current_level_id, last_replay)


func _on_replay() -> void:
	if last_replay.is_empty() and LevelManager.load_replay(GameManager.current_level_id).is_empty():
		return
	var events: Array = last_replay if not last_replay.is_empty() \
		else LevelManager.load_replay(GameManager.current_level_id)
	GameManager.reset()
	load_level(current_level_path, events)


func _on_retry() -> void:
	# Reload the CURRENT level in place rather than reloading the whole scene:
	# reload_current_scene() would re-instance game.tscn with its default
	# initial_level_path and restart from level 1 (and custom .json levels set
	# at runtime would be lost entirely).
	GameManager.reset()
	load_level(current_level_path)


func _on_back_to_menu() -> void:
	GameManager.reset()
	# Test-playing from the level editor returns into the editor.
	if LevelManager.editing_path != "":
		get_tree().change_scene_to_file("res://scenes/editor/level_editor.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
