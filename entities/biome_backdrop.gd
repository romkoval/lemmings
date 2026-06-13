class_name BiomeBackdrop
extends Control

# A procedural parallax-style backdrop drawn behind the terrain. Surface levels
# get a bright sky with a sun, layered mountain ranges and a tree line; cave
# levels get a dim rock gradient with hanging stalactites. The inferno keeps its
# own dark background (this node isn't used there). Screen-space (lives in the
# background CanvasLayer), redrawn on resize — no art assets.

@export var biome: String = "grass":
	set(v):
		biome = v
		queue_redraw()


func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(queue_redraw)


func _draw() -> void:
	if biome == "cave":
		_draw_cave()
	else:
		_draw_surface()


func _vgradient(top: float, bot: float, c_top: Color, c_bot: Color, strips: int = 28) -> void:
	var w: float = size.x
	var step: float = (bot - top) / float(strips)
	for s in range(strips):
		var t: float = float(s) / float(maxi(1, strips - 1))
		draw_rect(Rect2(0.0, top + step * float(s), w, step + 1.0), c_top.lerp(c_bot, t))


# Jagged silhouette: a ridge line sampled across the width, closed along the
# bottom. `seed_off` varies the peaks between ranges.
func _mountains(base_y: float, height: float, col: Color, seed_off: float, peaks: int) -> void:
	var w: float = size.x
	var pts := PackedVector2Array()
	pts.append(Vector2(0.0, size.y))
	pts.append(Vector2(0.0, base_y))
	for i in range(peaks + 1):
		var x: float = w * float(i) / float(peaks)
		var h: float = height * (0.45 + 0.55 * absf(sin(float(i) * 1.7 + seed_off)))
		pts.append(Vector2(x, base_y - h))
	pts.append(Vector2(w, base_y))
	pts.append(Vector2(w, size.y))
	draw_colored_polygon(pts, col)


func _draw_surface() -> void:
	var w: float = size.x
	var h: float = size.y
	# Sky: blue up high fading to a warm haze at the horizon.
	_vgradient(0.0, h, Color(0.42, 0.68, 0.93), Color(0.82, 0.88, 0.78))
	# Sun with a soft halo, upper right.
	var sun := Vector2(w * 0.78, h * 0.16)
	draw_circle(sun, 64.0, Color(1.0, 0.95, 0.7, 0.18))
	draw_circle(sun, 42.0, Color(1.0, 0.96, 0.78, 0.28))
	draw_circle(sun, 26.0, Color(1.0, 0.98, 0.85, 0.95))
	# Clouds — soft overlapping ellipses.
	for c in [Vector2(w * 0.2, h * 0.12), Vector2(w * 0.5, h * 0.22), Vector2(w * 0.62, h * 0.08)]:
		for dx in [-22.0, 0.0, 20.0, 40.0]:
			draw_circle(c + Vector2(dx, abs(dx) * 0.12), 18.0 - abs(dx) * 0.12, Color(1, 1, 1, 0.5))
	# Three mountain ranges, receding (lighter + higher up).
	_mountains(h * 0.60, h * 0.26, Color(0.52, 0.62, 0.72), 0.0, 7)
	_mountains(h * 0.66, h * 0.22, Color(0.40, 0.56, 0.50), 1.3, 9)
	_mountains(h * 0.72, h * 0.18, Color(0.28, 0.46, 0.30), 2.6, 11)
	# A distant tree line along the horizon band.
	var ty: float = h * 0.73
	for i in range(int(w / 46.0) + 1):
		var tx: float = 24.0 + i * 46.0
		_tree(Vector2(tx, ty + 6.0 * sin(float(i) * 1.4)), 0.85 + 0.25 * absf(sin(float(i) * 2.1)))


func _tree(base: Vector2, scl: float) -> void:
	# Simple silhouette: a trunk and two stacked canopy blobs.
	var trunk := Color(0.30, 0.22, 0.14)
	var leaf := Color(0.18, 0.42, 0.20)
	var leaf_hi := Color(0.26, 0.54, 0.26)
	draw_rect(Rect2(base + Vector2(-2.0 * scl, -16.0 * scl), Vector2(4.0 * scl, 18.0 * scl)), trunk)
	draw_circle(base + Vector2(0, -18.0 * scl), 11.0 * scl, leaf)
	draw_circle(base + Vector2(-6.0 * scl, -14.0 * scl), 8.0 * scl, leaf)
	draw_circle(base + Vector2(6.0 * scl, -14.0 * scl), 8.0 * scl, leaf)
	draw_circle(base + Vector2(-2.0 * scl, -21.0 * scl), 6.0 * scl, leaf_hi)


func _draw_cave() -> void:
	var w: float = size.x
	var h: float = size.y
	_vgradient(0.0, h, Color(0.12, 0.10, 0.14), Color(0.05, 0.04, 0.07))
	# Hanging stalactites from the ceiling and a few rising from the floor band.
	for i in range(int(w / 64.0) + 1):
		var x: float = float(i) * 64.0 + 18.0
		var sh: float = 40.0 + 30.0 * absf(sin(float(i) * 1.9))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 12, 0), Vector2(x + 12, 0), Vector2(x, sh)]),
			Color(0.16, 0.13, 0.17, 0.8))
	# Faint cracks of distant glow.
	for i in range(int(w / 120.0) + 1):
		var gx: float = float(i) * 120.0 + 60.0
		draw_circle(Vector2(gx, h * 0.5), 50.0, Color(0.3, 0.2, 0.35, 0.06))
