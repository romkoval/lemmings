class_name Game
extends Node2D

const HUD_SCENE: PackedScene = preload("res://ui/hud.tscn")
const RESULT_SCENE: PackedScene = preload("res://ui/result_screen.tscn")

@export var initial_level_path: String = ""

@onready var level_container: Node2D = $LevelContainer
@onready var hud_layer: CanvasLayer = $HUDLayer

var current_level: Level = null
var current_level_path: String = ""
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
	hud.nuke_pressed.connect(_on_nuke)
	hud.skill_chosen.connect(_on_skill_chosen)
	skill_manager.skill_count_changed.connect(_on_skill_count_changed)
	hud.time_expired.connect(_on_time_expired)
	GameManager.all_lemmings_resolved.connect(_on_all_resolved)

	result_screen = RESULT_SCENE.instantiate()
	hud_layer.add_child(result_screen)
	result_screen.retry_pressed.connect(_on_retry)
	result_screen.menu_pressed.connect(_on_back_to_menu)
	result_screen.next_pressed.connect(_on_next)
	GameManager.level_completed.connect(_on_level_completed)
	GameManager.level_failed.connect(_on_level_failed)

	AudioManager.play_music("theme")

	var path: String = initial_level_path
	if path == "":
		path = "res://levels/fun/level_01.tscn"
	if ResourceLoader.exists(path):
		load_level(path)


func load_level(scene_path: String) -> void:
	if current_level:
		current_level.queue_free()
	var scene: PackedScene = load(scene_path)
	if scene == null:
		return
	if result_screen:
		result_screen.visible = false
	current_level_path = scene_path
	current_level = scene.instantiate() as Level
	level_container.add_child(current_level)
	skill_manager.configure(current_level.skill_counts)
	hud.configure(
		current_level.total_lemmings,
		current_level.save_required,
		current_level.time_limit,
		skill_manager.skill_counts,
	)
	GameManager.start_level(current_level.level_id, current_level.total_lemmings)


func _input(event: InputEvent) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		_set_highlight(null)
		return
	# emulate_touch_from_mouse is on, so a desktop click arrives as a touch too —
	# handle assignment only via touch to avoid assigning twice.
	if event is InputEventMouseMotion:
		_update_highlight(get_global_mouse_position())
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			# event.position is in screen space — map it into the world.
			_try_assign_at(_screen_to_world(st.position))
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_update_highlight(_screen_to_world(sd.position))


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


func _try_assign_at(world_pos: Vector2) -> void:
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
	var best: Lemming = null
	var best_d: float = max_dist
	for n in get_tree().get_nodes_in_group("lemmings"):
		var lem := n as Lemming
		if lem == null:
			continue
		var d: float = lem.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = lem
	return best


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
	lemming_manager.nuke_all()


func _on_all_resolved() -> void:
	GameManager.complete_level(current_level.save_required)


func _on_time_expired() -> void:
	if GameManager.current_state == GameManager.GameState.PLAYING:
		GameManager.complete_level(current_level.save_required)


func _on_level_completed(saved: int, required: int) -> void:
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
	result_screen.show_result(false, GameManager.saved_count, current_level.save_required, current_level.total_lemmings)


func _on_retry() -> void:
	GameManager.reset()
	get_tree().reload_current_scene()


func _on_back_to_menu() -> void:
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
