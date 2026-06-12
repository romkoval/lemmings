extends Control

# Browser for player-made levels: create a new one, or play / edit / delete a
# saved one. Levels live in user://custom_levels/*.json and are played through
# the regular game scene (ProceduralLevel + per-pixel terrain).

@onready var list_container: VBoxContainer = $Scroll/List
@onready var new_button: Button = $TopBar/NewButton
@onready var back_button: Button = $TopBar/BackButton


var _import_button: Button = null
var _status: Label = null


func _ready() -> void:
	new_button.pressed.connect(_on_new)
	back_button.pressed.connect(_on_back)
	# Import any .lemlvl bundles dropped into user://custom_levels/ (US-4.1):
	# on desktop copy the file there; on mobile via the Files app share.
	_import_button = Button.new()
	_import_button.text = "Импорт"
	_import_button.custom_minimum_size = Vector2(0, new_button.custom_minimum_size.y)
	_import_button.add_theme_font_size_override("font_size", 20)
	_import_button.pressed.connect(_on_import)
	new_button.get_parent().add_child(_import_button)
	new_button.get_parent().move_child(_import_button, new_button.get_index() + 1)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 18)
	list_container.get_parent().get_parent().add_child(_status)
	_refresh()


func _on_import() -> void:
	var imported := 0
	var dir := DirAccess.open(LevelManager.CUSTOM_LEVELS_DIR)
	if dir != null:
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while fname != "":
			if fname.ends_with(".lemlvl"):
				var path: String = LevelManager.CUSTOM_LEVELS_DIR + fname
				if LevelManager.import_level(path) != "":
					imported += 1
					DirAccess.remove_absolute(path)
			fname = dir.get_next()
		dir.list_dir_end()
	_status.text = ("Импортировано уровней: %d" % imported) if imported > 0 \
		else "Положите .lemlvl в папку custom_levels и нажмите «Импорт»"
	_refresh()


func _on_export(info: Dictionary) -> void:
	var out: String = LevelManager.export_level(str(info["path"]))
	_status.text = ("Экспортировано: %s" % out.get_file()) if out != "" else "Ошибка экспорта"


func _refresh() -> void:
	for child in list_container.get_children():
		child.queue_free()
	var levels: Array = LevelManager.list_custom_levels()
	if levels.is_empty():
		var empty := Label.new()
		empty.text = "Пока нет своих уровней.\nНажмите «Новый уровень», чтобы создать первый!"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 22)
		list_container.add_child(empty)
		return
	for info: Dictionary in levels:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list_container.add_child(row)
		var name_label := Label.new()
		# "✓" = the author beat their own level in a test-play (US-4.2 proof).
		name_label.text = ("✓ " if bool(info.get("verified", false)) else "") + str(info["name"])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.clip_text = true
		row.add_child(name_label)
		row.add_child(_mk_button("▶", _on_play.bind(info), Vector2(64, 56)))
		row.add_child(_mk_button("✎", _on_edit.bind(info), Vector2(64, 56)))
		row.add_child(_mk_button("⇪", _on_export.bind(info), Vector2(64, 56)))
		row.add_child(_mk_button("✕", _on_delete.bind(info), Vector2(64, 56)))


func _mk_button(text: String, handler: Callable, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(handler)
	return b


func _on_new() -> void:
	LevelManager.editing_path = ""
	get_tree().change_scene_to_file("res://scenes/editor/level_editor.tscn")


func _on_edit(info: Dictionary) -> void:
	LevelManager.editing_path = str(info["path"])
	get_tree().change_scene_to_file("res://scenes/editor/level_editor.tscn")


func _on_play(info: Dictionary) -> void:
	LevelManager.editing_path = ""
	GameManager.current_level_id = str(info["id"])
	var game_scene: PackedScene = load("res://scenes/game/game.tscn")
	var game := game_scene.instantiate()
	game.set("initial_level_path", str(info["path"]))
	get_tree().root.add_child(game)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = game


func _on_delete(info: Dictionary) -> void:
	LevelManager.delete_custom_level(str(info["path"]))
	_refresh()


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
