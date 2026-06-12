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


func _draw_fire() -> void:
	draw_rect(Rect2(Vector2.ZERO, zone_size), Color(0.80, 0.22, 0.04, 0.50))
	if zone_size.y > 24.0:
		draw_rect(Rect2(0.0, zone_size.y * 0.5, zone_size.x, zone_size.y * 0.5),
			Color(0.55, 0.10, 0.02, 0.50))
	# Flickering flame tongues along the top edge.
	var n: int = maxi(3, int(zone_size.x / 16.0))
	for i in range(n):
		var cx: float = zone_size.x * (float(i) + 0.5) / float(n)
		var h: float = 7.0 + 6.0 * (0.5 + 0.5 * sin(_t * 7.0 + float(i) * 1.7))
		var w: float = zone_size.x / float(n) * 0.42
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - w, 2.0), Vector2(cx + w, 2.0), Vector2(cx, -h)]),
			Color(1.0, 0.55, 0.10, 0.75))
