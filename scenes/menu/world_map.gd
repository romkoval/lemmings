class_name WorldMap
extends Control

# The campaign as a journey: every level is a node on a winding trail that
# descends through three biome zones — grassy surface, brown dungeon, then the
# lava of the inferno. A lemming avatar stands at the frontier (the next level
# to play) and walks one step forward each time you open the map after winning.
# Nodes unlock in sequence; tapping an open one drops you into that level.
#
# Everything but the avatar and the chrome is drawn procedurally in _draw,
# offset by a manual vertical scroll (drag to pan), so the trail can be any
# length without art assets.

const TOP_MARGIN := 160.0
const BOTTOM_MARGIN := 220.0
const SPACING := 156.0          # vertical gap between level nodes
const AMP := 200.0              # how far the trail swings left/right
const NODE_R := 30.0
const TAP_SLOP := 14.0
const WALK_TIME := 1.1          # avatar step from the last node to the frontier

# Per-biome palette: zone background gradient, trail colour, node fill.
const BIOMES := {
	"grass": {
		"bg_top": Color(0.42, 0.66, 0.34), "bg_bot": Color(0.24, 0.42, 0.20),
		"trail": Color(0.52, 0.39, 0.22), "node": Color(0.50, 0.82, 0.38),
		"label": "Луга",
	},
	"dungeon": {
		"bg_top": Color(0.32, 0.25, 0.18), "bg_bot": Color(0.16, 0.12, 0.09),
		"trail": Color(0.46, 0.35, 0.23), "node": Color(0.80, 0.58, 0.32),
		"label": "Подземелье",
	},
	"inferno": {
		"bg_top": Color(0.30, 0.10, 0.06), "bg_bot": Color(0.10, 0.03, 0.03),
		"trail": Color(0.42, 0.18, 0.10), "node": Color(1.0, 0.55, 0.15),
		"label": "Инферно",
	},
}

var nodes: Array = []           # built from LevelManager.campaign_order()
var _decor: Array = []          # static biome decorations, computed once
var content_height: float = 0.0
var _scroll: float = 0.0
var _vel: float = 0.0
var _max_scroll: float = 0.0

var _dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _press_scroll: float = 0.0
var _moved: float = 0.0

var avatar: LemmingSprite = null
var _avatar_pos: Vector2 = Vector2.ZERO    # content-space position
var _walk_t: float = -1.0                  # ≥0 while stepping to the frontier
var _walk_from: Vector2 = Vector2.ZERO
var _bob: float = 0.0

@onready var back_button: Button = $BackButton
@onready var title: Label = $Title
@onready var progress_label: Label = $Progress
@onready var font: Font = ThemeDB.fallback_font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	MenuTheme.style_title(title, 44)
	MenuTheme.style_button(back_button, MenuTheme.ACCENT_BACK, 26)
	back_button.pressed.connect(_on_back)
	progress_label.add_theme_font_size_override("font_size", 24)
	progress_label.add_theme_color_override("font_color", MenuTheme.TEXT)
	progress_label.add_theme_color_override("font_outline_color", Color.BLACK)
	progress_label.add_theme_constant_override("outline_size", 4)

	rebuild()
	_make_decor()

	avatar = LemmingSprite.new()
	avatar.scale = Vector2(2.4, 2.4)
	add_child(avatar)

	get_viewport().size_changed.connect(_recompute_scroll_limits)
	_recompute_scroll_limits()
	_start_at_frontier()
	if not AudioManager.music_player.playing:
		AudioManager.play_music("theme")


# ── Data ────────────────────────────────────────────────────────────────────

# Build the node list with live progress flags. A node is unlocked when the
# previous one in the journey is complete (the first is always open).
func rebuild() -> void:
	nodes.clear()
	var order: Array = LevelManager.campaign_order()
	var prev_complete: bool = true
	for i in order.size():
		var e: Dictionary = order[i]
		var complete: bool = SaveManager.is_level_complete(str(e["id"]))
		nodes.append({
			"category": e["category"], "number": e["number"], "id": e["id"],
			"name": e["name"], "biome": e["biome"], "pos": Vector2.ZERO,
			"complete": complete, "unlocked": prev_complete, "index": i,
			"best": SaveManager.best_result(str(e["id"])),
		})
		prev_complete = complete
	content_height = TOP_MARGIN + maxf(0.0, float(nodes.size() - 1)) * SPACING + BOTTOM_MARGIN
	_layout_positions()


# Place each node along the winding trail, centred on the current viewport width
# so the path stays centred on any screen (portrait phone or wide window).
func _layout_positions() -> void:
	var cx: float = size.x * 0.5
	var amp: float = minf(AMP, size.x * 0.5 - 120.0)
	for i in nodes.size():
		nodes[i]["pos"] = Vector2(
			cx + amp * sin(float(i) * 0.9 + 0.6),
			TOP_MARGIN + float(i) * SPACING)
	if progress_label:
		var done := 0
		for n in nodes:
			if n["complete"]:
				done += 1
		progress_label.text = "%d / %d" % [done, nodes.size()]


# The frontier: the first open, not-yet-cleared level — where the avatar waits.
# If everything is done, the last node.
func frontier_index() -> int:
	for n in nodes:
		if n["unlocked"] and not n["complete"]:
			return int(n["index"])
	return maxi(0, nodes.size() - 1)


# Node whose disc contains a content-space point, or {} if none.
func node_at_content(p: Vector2) -> Dictionary:
	for n in nodes:
		if (n["pos"] as Vector2).distance_to(p) <= NODE_R + 6.0:
			return n
	return {}


func _make_decor() -> void:
	_decor.clear()
	# A handful of fixed (deterministic) flecks per node band so the zones feel
	# alive without per-frame jitter: grass blades, dungeon bricks, embers.
	for n in nodes:
		var biome: String = n["biome"]
		var base: Vector2 = n["pos"]
		for k in range(3):
			var sx: float = wrapf(base.x + (k * 53 + n["index"] * 71) % 520 - 260, 60.0, 660.0)
			var sy: float = base.y - SPACING * 0.5 + float((k * 37 + n["index"] * 29) % int(SPACING))
			_decor.append({"biome": biome, "pos": Vector2(sx, sy), "k": k})


# ── Scroll ────────────────────────────────────────────────────────────────

func _recompute_scroll_limits() -> void:
	_layout_positions()   # width may have changed → re-centre the trail
	_make_decor()
	_max_scroll = maxf(0.0, content_height - size.y)
	_scroll = clampf(_scroll, 0.0, _max_scroll)


func _start_at_frontier() -> void:
	if nodes.is_empty():
		return
	var f: int = frontier_index()
	var fnode: Dictionary = nodes[f]
	# Centre the frontier; the avatar walks in from the previous node.
	_scroll = clampf((fnode["pos"] as Vector2).y - size.y * 0.5, 0.0, _max_scroll)
	if f > 0:
		_avatar_pos = nodes[f - 1]["pos"]
		_walk_from = _avatar_pos
		_walk_t = 0.0
	else:
		_avatar_pos = fnode["pos"]
		_walk_t = -1.0


func _to_screen(content_pos: Vector2) -> Vector2:
	return content_pos - Vector2(0.0, _scroll)


# ── Frame ───────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_bob += delta
	# Inertial scroll when not actively dragging.
	if not _dragging and absf(_vel) > 1.0:
		_scroll = clampf(_scroll + _vel * delta, 0.0, _max_scroll)
		_vel = move_toward(_vel, 0.0, 1400.0 * delta)
		if _scroll <= 0.0 or _scroll >= _max_scroll:
			_vel = 0.0
	# Avatar: walk to the frontier on entry, then idle-bob on its node.
	var target: Vector2 = _avatar_pos
	if _walk_t >= 0.0 and not nodes.is_empty():
		_walk_t += delta
		var f: int = frontier_index()
		var to: Vector2 = nodes[f]["pos"]
		var a: float = clampf(_walk_t / WALK_TIME, 0.0, 1.0)
		_avatar_pos = _walk_from.lerp(to, a)
		avatar.dir = -1 if to.x < _walk_from.x else 1
		if a >= 1.0:
			_walk_t = -1.0
			_avatar_pos = to
		target = _avatar_pos
	if avatar:
		var lift: float = NODE_R + 14.0 + (2.0 * sin(_bob * 4.0) if _walk_t < 0.0 else 0.0)
		avatar.position = _to_screen(target) - Vector2(0.0, lift)
	queue_redraw()


# ── Input: drag to scroll, tap a node to play ────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_vel = 0.0
			_scroll = clampf(_scroll + 90.0, 0.0, _max_scroll)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_vel = 0.0
			_scroll = clampf(_scroll - 90.0, 0.0, _max_scroll)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin_drag(event.position)
			else:
				_end_drag(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag(event.position)
	elif event is InputEventMouseMotion and _dragging:
		_drag_to(event.position)
	elif event is InputEventScreenDrag and _dragging:
		_drag_to(event.position)


func _begin_drag(pos: Vector2) -> void:
	_dragging = true
	_press_pos = pos
	_press_scroll = _scroll
	_moved = 0.0
	_vel = 0.0


func _drag_to(pos: Vector2) -> void:
	var dy: float = pos.y - _press_pos.y
	_moved = maxf(_moved, absf(dy))
	var prev: float = _scroll
	_scroll = clampf(_press_scroll - dy, 0.0, _max_scroll)
	_vel = (_scroll - prev) / maxf(0.001, get_process_delta_time())


func _end_drag(pos: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	if _moved <= TAP_SLOP:
		_tap(pos)


func _tap(screen_pos: Vector2) -> void:
	var content_pos := screen_pos + Vector2(0.0, _scroll)
	var n: Dictionary = node_at_content(content_pos)
	if n.is_empty() or not n["unlocked"]:
		if not n.is_empty():
			AudioManager.play_sfx("skill_assign")   # a soft "nope" cue (locked)
		return
	_enter_level(str(n["category"]), int(n["number"]))


func _enter_level(category: String, number: int) -> void:
	var scene_path: String = LevelManager.get_scene_path(category, number)
	if not ResourceLoader.exists(scene_path):
		push_warning("Scene not found: %s" % scene_path)
		return
	GameManager.current_level_id = "%s_%02d" % [category, number]
	LevelManager.editing_path = ""
	var game: Node = (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	game.set("initial_level_path", scene_path)
	get_tree().root.add_child(game)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = game


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


# ── Drawing ───────────────────────────────────────────────────────────────

func _draw() -> void:
	if nodes.is_empty():
		return
	_draw_biome_bands()
	_draw_decor()
	_draw_trail()
	for n in nodes:
		_draw_node(n)


# Vertical gradient backgrounds, one contiguous band per biome zone, with a
# glowing divider + zone name where the biome changes.
func _draw_biome_bands() -> void:
	var i := 0
	while i < nodes.size():
		var biome: String = nodes[i]["biome"]
		var j := i
		while j < nodes.size() and nodes[j]["biome"] == biome:
			j += 1
		var top: float = 0.0 if i == 0 else ((nodes[i - 1]["pos"].y + nodes[i]["pos"].y) * 0.5)
		var bot: float = content_height if j >= nodes.size() else ((nodes[j - 1]["pos"].y + nodes[j]["pos"].y) * 0.5)
		_vgradient(top, bot, BIOMES[biome]["bg_top"], BIOMES[biome]["bg_bot"])
		# Zone label near the band's top, parked at the side.
		var ly: float = _to_screen(Vector2.ZERO).y + top + 30.0
		draw_string(font, Vector2(28.0, ly), tr(str(BIOMES[biome]["label"])),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.5))
		if i > 0:
			var dy: float = _to_screen(Vector2(0, top)).y
			draw_line(Vector2(0, dy), Vector2(size.x, dy), Color(0, 0, 0, 0.35), 3.0)
		i = j


func _vgradient(content_top: float, content_bot: float, c_top: Color, c_bot: Color) -> void:
	var top: float = _to_screen(Vector2(0, content_top)).y
	var bot: float = _to_screen(Vector2(0, content_bot)).y
	var strips := 26
	var step: float = (bot - top) / float(strips)
	for s in range(strips):
		var t: float = float(s) / float(strips - 1)
		draw_rect(Rect2(0.0, top + step * s, size.x, step + 1.0), c_top.lerp(c_bot, t))


func _draw_decor() -> void:
	for d in _decor:
		var p: Vector2 = _to_screen(d["pos"])
		if p.y < -20.0 or p.y > size.y + 20.0:
			continue
		match d["biome"]:
			"grass":
				draw_colored_polygon(PackedVector2Array([
					p, p + Vector2(-3, -12), p + Vector2(3, -12)]),
					Color(0.38, 0.70, 0.30, 0.7))
			"dungeon":
				draw_rect(Rect2(p, Vector2(16, 8)), Color(0.30, 0.23, 0.16, 0.6))
			"inferno":
				draw_circle(p, 2.0 + float(d["k"]), Color(1.0, 0.5, 0.12, 0.5))


func _draw_trail() -> void:
	for i in range(nodes.size() - 1):
		var a: Vector2 = _to_screen(nodes[i]["pos"])
		var b: Vector2 = _to_screen(nodes[i + 1]["pos"])
		# A segment is "travelled" (gold) once its lower node is complete.
		var travelled: bool = nodes[i]["complete"]
		var col: Color = BIOMES[nodes[i]["biome"]]["trail"]
		draw_line(a, b, Color(0, 0, 0, 0.4), 16.0)
		draw_line(a, b, col if not travelled else Color(1.0, 0.82, 0.3), 10.0)


func _draw_node(n: Dictionary) -> void:
	var c: Vector2 = _to_screen(n["pos"])
	if c.y < -NODE_R * 2.0 or c.y > size.y + NODE_R * 2.0:
		return
	var biome: Dictionary = BIOMES[n["biome"]]
	if not n["unlocked"]:
		# Locked: grey disc with a little padlock.
		draw_circle(c, NODE_R, Color(0.22, 0.22, 0.26))
		draw_arc(c, NODE_R, 0, TAU, 32, Color(0.12, 0.12, 0.15), 4.0)
		draw_rect(Rect2(c + Vector2(-8, -2), Vector2(16, 13)), Color(0.55, 0.55, 0.6))
		draw_arc(c + Vector2(0, -2), 6.0, PI, TAU, 12, Color(0.55, 0.55, 0.6), 3.0)
		return
	var fill: Color = biome["node"]
	# Frontier node: a pulsing halo.
	if n["index"] == frontier_index() and not n["complete"]:
		var pulse: float = 0.5 + 0.5 * sin(_bob * 4.0)
		draw_circle(c, NODE_R + 8.0 + 4.0 * pulse, Color(fill.r, fill.g, fill.b, 0.25))
	draw_circle(c, NODE_R, fill)
	draw_arc(c, NODE_R, 0, TAU, 36, fill.darkened(0.4), 4.0)
	if n["complete"]:
		# Check mark + star rating from the best save ratio.
		draw_polyline(PackedVector2Array([
			c + Vector2(-11, 0), c + Vector2(-3, 9), c + Vector2(12, -10)]),
			Color(0.1, 0.25, 0.1), 4.0)
		_draw_stars(c + Vector2(0, NODE_R + 14.0), n["best"])
	else:
		draw_string(font, c + Vector2(-9, 9), str(n["number"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.1, 0.08, 0.05))
	# Level name beneath unlocked nodes.
	if str(n["name"]) != "":
		var nm: String = str(n["name"])
		var label_y: float = NODE_R + (34.0 if n["complete"] else 22.0)
		draw_string(font, c + Vector2(-100, label_y), nm, HORIZONTAL_ALIGNMENT_CENTER,
			200, 20, Color(1, 1, 1, 0.85))


func _draw_stars(at: Vector2, best: Dictionary) -> void:
	var ratio: float = 0.0
	if not best.is_empty() and int(best.get("total", 0)) > 0:
		ratio = float(best.get("saved", 0)) / float(best.get("total", 1))
	var filled := 1
	if ratio >= 0.99:
		filled = 3
	elif ratio >= 0.75:
		filled = 2
	for s in range(3):
		var col := Color(1.0, 0.85, 0.3) if s < filled else Color(0.4, 0.4, 0.45)
		draw_circle(at + Vector2((s - 1) * 13.0, 0.0), 4.0, col)
