class_name HazardZone
extends Area2D

# A deadly area — water or fire (US-1.3). Any lemming whose body enters dies:
# floaters and climbers included, exactly like the original — only the exit
# saves a lemming, never a hazard. The visual is drawn procedurally (animated
# waves / flame tongues), so a zone stretches to any rect without art assets.
# Position is the rect's top-left corner; zone_size its extent.

enum HazardType { WATER, FIRE }

const TYPE_NAMES: Dictionary = {HazardType.WATER: "water", HazardType.FIRE: "fire"}
const DEATH_CAUSES: Dictionary = {HazardType.WATER: "drowned", HazardType.FIRE: "burned"}
const MIN_SIZE: Vector2 = Vector2(16.0, 16.0)

@export var hazard_type: HazardType = HazardType.WATER:
	set(v):
		hazard_type = v
		queue_redraw()
@export var zone_size: Vector2 = Vector2(96, 48):
	set(v):
		zone_size = v.max(MIN_SIZE)
		_sync_shape()
		queue_redraw()

var _shape: CollisionShape2D = null
var _t: float = 0.0


static func type_from_name(n: String) -> HazardType:
	return HazardType.FIRE if n == "fire" else HazardType.WATER


func _ready() -> void:
	add_to_group("hazards")
	collision_layer = 8
	collision_mask = 2   # lemming bodies
	monitoring = true
	body_entered.connect(_on_body_entered)
	_sync_shape()


func rect_px() -> Rect2:
	return Rect2(position, zone_size)


func _sync_shape() -> void:
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.shape = RectangleShape2D.new()
		add_child(_shape)
	(_shape.shape as RectangleShape2D).size = zone_size
	_shape.position = zone_size * 0.5


func _on_body_entered(body: Node) -> void:
	var lem := body as Lemming
	if lem == null or lem.current_state in Lemming.TERMINAL_STATES:
		return
	lem.die(DEATH_CAUSES[hazard_type])


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if hazard_type == HazardType.WATER:
		_draw_water()
	else:
		_draw_fire()


func _draw_water() -> void:
	draw_rect(Rect2(Vector2.ZERO, zone_size), Color(0.10, 0.30, 0.65, 0.55))
	# Deeper water is darker.
	if zone_size.y > 24.0:
		draw_rect(Rect2(0.0, zone_size.y * 0.5, zone_size.x, zone_size.y * 0.5),
			Color(0.05, 0.16, 0.42, 0.45))
	# Animated surface line.
	var pts := PackedVector2Array()
	var n: int = maxi(4, int(zone_size.x / 12.0))
	for i in range(n + 1):
		var x: float = zone_size.x * float(i) / float(n)
		pts.append(Vector2(x, 3.0 + 2.2 * sin(_t * 2.2 + x * 0.08)))
	draw_polyline(pts, Color(0.75, 0.92, 1.0, 0.85), 1.5)


# Fire is built from five stacked effects, all animated off _t (no textures):
# a lava body whose crust glows and dims, hot surface blobs, a heat halo above
# the surface, two depths of swaying flame tongues (dark back / bright front
# with yellow cores), and embers drifting up. Every per-element phase is a
# function of the element index, so the flames are alive but deterministic.
const LAVA_BANDS: Array[Color] = [
	Color(1.00, 0.60, 0.12, 0.95),   # molten crust
	Color(0.90, 0.32, 0.05, 0.92),
	Color(0.58, 0.13, 0.03, 0.90),
	Color(0.30, 0.05, 0.02, 0.90),   # cooling depths
]


func _draw_fire() -> void:
	var w: float = zone_size.x
	var h: float = zone_size.y
	# A zone much taller than wide reads as a lava fall, not a lake.
	if h > w * 2.0:
		_draw_lavafall(w, h)
		return
	# Lava body: hot crust fading into dark depths.
	var band_h: float = h / float(LAVA_BANDS.size())
	for i in range(LAVA_BANDS.size()):
		draw_rect(Rect2(0.0, band_h * float(i), w, band_h + 1.0), LAVA_BANDS[i])
	# Breathing bright blobs on the crust.
	for k in range(maxi(2, int(w / 26.0))):
		var bx: float = fposmod((float(k) + 0.5) * 26.0 + 7.0 * sin(_t * 0.6 + float(k) * 2.1), w)
		var pulse: float = 0.5 + 0.5 * sin(_t * 1.7 + float(k) * 2.7)
		draw_circle(Vector2(bx, 4.5 + 1.5 * pulse), 4.0 + 3.0 * pulse,
			Color(1.0, 0.78, 0.22, 0.20 + 0.22 * pulse))
	# Heat shimmer hugging the surface — low, so the fire reads as lava at the
	# walking surface, not a towering object.
	for g in range(2):
		var gh: float = 3.0 * float(g + 1)
		draw_rect(Rect2(0.0, -gh, w, gh), Color(1.0, 0.45, 0.08, 0.09 - 0.03 * float(g)))
	# Back flames: low licking tongues, deep red.
	for i in range(maxi(2, int(w / 20.0))):
		var bcx: float = (float(i) + 0.5) * 20.0
		var bfh: float = 5.0 + 5.0 * _flick(_t * 2.6, float(i))
		_draw_tongue(bcx, 7.0, bfh, 2.5 * sin(_t * 1.9 + float(i) * 1.93),
			Color(0.82, 0.20, 0.04, 0.60))
	# Front flames: short, fast, bright orange with a yellow core.
	for i in range(maxi(3, int(w / 13.0))):
		var cx: float = (float(i) + 0.86) * 13.0
		var fh: float = 4.0 + 6.0 * _flick(_t * 5.1, float(i) * 1.7)
		var sway: float = 2.0 * sin(_t * 3.1 + float(i) * 2.39)
		_draw_tongue(cx, 5.0, fh, sway, Color(1.0, 0.58, 0.08, 0.88))
		_draw_tongue(cx, 2.6, fh * 0.58, sway * 0.7, Color(1.0, 0.88, 0.35, 0.85))
	# White-hot surface line.
	draw_rect(Rect2(0.0, 0.0, w, 1.6), Color(1.0, 0.92, 0.55, 0.65))
	# A few embers drifting just above the surface and burning out.
	for j in range(maxi(2, int(w / 40.0))):
		var cycle: float = fposmod(_t * (0.30 + 0.13 * fposmod(float(j) * 0.61, 1.0)) + float(j) * 0.41, 1.0)
		var ex: float = fposmod(float(j) * 40.0 + 13.0, w) + 5.0 * sin(cycle * TAU * 1.4 + float(j))
		var ey: float = -1.0 - cycle * (12.0 + 6.0 * fposmod(float(j) * 0.83, 1.0))
		var fade: float = 1.0 - cycle
		draw_circle(Vector2(ex, ey), 1.0 + 0.7 * fade,
			Color(1.0, 0.55 + 0.35 * fade, 0.15, 0.8 * fade))


# A vertical molten stream: dark edges, a white-hot pulsing core, bright
# clots streaming down and a splash of flames where it lands.
func _draw_lavafall(w: float, h: float) -> void:
	var cx: float = w * 0.5
	draw_rect(Rect2(0.0, 0.0, w, h), Color(0.55, 0.10, 0.02, 0.85))
	# Source: a molten lip that bulges out wider than the stream at the very top,
	# with a small overflow pool — so the fall visibly spills from the rock above
	# rather than appearing out of nowhere.
	var lip_w: float = w * (1.6 + 0.2 * sin(_t * 2.4))
	draw_rect(Rect2(cx - lip_w * 0.5, -3.0, lip_w, 6.0), Color(1.0, 0.55, 0.10, 0.9))
	draw_rect(Rect2(cx - lip_w * 0.5, -1.0, lip_w, 3.0), Color(1.0, 0.85, 0.35, 0.85))
	for d in range(3):
		var dx: float = (float(d) - 1.0) * w * 0.5
		draw_circle(Vector2(cx + dx, 1.0 + 1.5 * sin(_t * 3.0 + float(d))), 2.2,
			Color(1.0, 0.7, 0.2, 0.8))
	# Core: width breathes along the height and in time.
	var seg: int = maxi(4, int(h / 14.0))
	for i in range(seg):
		var y0: float = h * float(i) / float(seg)
		var cw: float = w * (0.42 + 0.16 * sin(_t * 3.1 + float(i) * 0.9))
		draw_rect(Rect2(cx - cw * 0.5, y0, cw, h / float(seg) + 1.0),
			Color(1.0, 0.55, 0.10, 0.85))
		draw_rect(Rect2(cx - cw * 0.18, y0, cw * 0.36, h / float(seg) + 1.0),
			Color(1.0, 0.88, 0.40, 0.80))
	# Clots streaming down.
	for j in range(maxi(3, int(h / 26.0))):
		var cyc: float = fposmod(_t * (0.55 + 0.2 * fposmod(float(j) * 0.71, 1.0)) + float(j) * 0.37, 1.0)
		var jy: float = cyc * h
		draw_circle(Vector2(cx + 2.5 * sin(float(j) * 2.1), jy), 1.6 + 1.2 * (1.0 - cyc),
			Color(1.0, 0.80, 0.30, 0.9))
	# Splash at the foot.
	for k in range(3):
		var sx: float = cx + (float(k) - 1.0) * w * 0.42
		var fh: float = 5.0 + 5.0 * _flick(_t * 4.3, float(k) * 1.7)
		_draw_tongue_at(sx, h, 3.5, fh, 2.0 * sin(_t * 3.7 + float(k) * 2.1),
			Color(1.0, 0.62, 0.12, 0.85))


# Two interleaved sines give an organic, non-repeating flicker in 0..1.
func _flick(t: float, phase: float) -> float:
	return clampf(0.5 + 0.34 * sin(t + phase * 2.39) + 0.21 * sin(t * 2.33 + phase * 4.1), 0.0, 1.0)


# One flame tongue: a pointed polygon with a waist; the tip leans with `sway`.
func _draw_tongue(cx: float, base_w: float, fh: float, sway: float, col: Color) -> void:
	_draw_tongue_at(cx, 0.0, base_w, fh, sway, col)


func _draw_tongue_at(cx: float, base_y: float, base_w: float, fh: float, sway: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - base_w, base_y + 2.0),
		Vector2(cx - base_w * 0.62, base_y - fh * 0.30),
		Vector2(cx - base_w * 0.28 + sway * 0.4, base_y - fh * 0.64),
		Vector2(cx + sway, base_y - fh),
		Vector2(cx + base_w * 0.28 + sway * 0.4, base_y - fh * 0.60),
		Vector2(cx + base_w * 0.62, base_y - fh * 0.26),
		Vector2(cx + base_w, base_y + 2.0),
	]), col)
