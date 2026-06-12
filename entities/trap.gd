class_name Trap
extends Area2D

# A triggered trap (US-1.4): sits armed until a lemming steps into its trigger
# area, snaps — killing exactly that one lemming — then resets through a
# cooldown during which the rest of the crowd walks past unharmed. That cycle
# is the classic way traps meter a column instead of annihilating it.
# Visuals are procedural (like HazardZone): a crusher piston or snapping jaws,
# so no art assets are needed. Position is the trigger rect's top-left.

enum TrapType { CRUSHER, CLAMP }
enum Phase { IDLE, SNAP, COOLDOWN }

const TYPE_NAMES: Dictionary = {TrapType.CRUSHER: "crusher", TrapType.CLAMP: "clamp"}
const TRIGGER_SIZE: Vector2 = Vector2(24.0, 24.0)
const SNAP_TIME: float = 0.45
const COOLDOWN_TIME: float = 0.9

@export var trap_type: TrapType = TrapType.CRUSHER:
	set(v):
		trap_type = v
		queue_redraw()

var phase: Phase = Phase.IDLE
var _phase_t: float = 0.0


static func type_from_name(n: String) -> TrapType:
	return TrapType.CLAMP if n == "clamp" else TrapType.CRUSHER


func _ready() -> void:
	add_to_group("traps")
	collision_layer = 8
	collision_mask = 2   # lemming bodies
	monitoring = true
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	(shape.shape as RectangleShape2D).size = TRIGGER_SIZE
	shape.position = TRIGGER_SIZE * 0.5
	add_child(shape)


func rect_px() -> Rect2:
	return Rect2(position, TRIGGER_SIZE)


func _physics_process(delta: float) -> void:
	# Frozen while paused — a trap must never fire on a lemming that is merely
	# standing still because the game is paused.
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	match phase:
		Phase.IDLE:
			# Overlap scan (not body_entered): also catches a lemming that was
			# already inside when the trap re-armed.
			for body in get_overlapping_bodies():
				var lem := body as Lemming
				if lem != null and lem.current_state not in Lemming.TERMINAL_STATES:
					lem.die("trapped")
					_phase_t = 0.0
					phase = Phase.SNAP
					break
		Phase.SNAP:
			_phase_t += delta
			if _phase_t >= SNAP_TIME:
				_phase_t = 0.0
				phase = Phase.COOLDOWN
		Phase.COOLDOWN:
			_phase_t += delta
			if _phase_t >= COOLDOWN_TIME:
				phase = Phase.IDLE


func _process(_delta: float) -> void:
	queue_redraw()


# 0 = armed/retracted, 1 = fully snapped. Snaps fast, retracts slowly.
func _extension() -> float:
	match phase:
		Phase.SNAP:
			return minf(1.0, _phase_t / (SNAP_TIME * 0.4))
		Phase.COOLDOWN:
			return 1.0 - clampf(_phase_t / COOLDOWN_TIME, 0.0, 1.0)
		_:
			return 0.0


func _draw() -> void:
	if trap_type == TrapType.CRUSHER:
		_draw_crusher()
	else:
		_draw_clamp()


func _draw_crusher() -> void:
	var ts := TRIGGER_SIZE
	var ext := _extension()
	var steel_dark := Color(0.30, 0.32, 0.38)
	var steel_mid := Color(0.52, 0.55, 0.62)
	# Housing above the trigger area.
	draw_rect(Rect2(-3.0, -34.0, ts.x + 6.0, 10.0), steel_dark)
	draw_rect(Rect2(-3.0, -34.0, ts.x + 6.0, 3.0), steel_mid)
	# Side rails the head slides on.
	draw_rect(Rect2(-3.0, -24.0, 3.0, ts.y + 24.0), steel_dark)
	draw_rect(Rect2(ts.x, -24.0, 3.0, ts.y + 24.0), steel_dark)
	# Piston shaft + head: extends from the housing down over the trigger.
	var reach: float = ext * (ts.y + 18.0)
	draw_rect(Rect2(ts.x * 0.5 - 3.0, -24.0, 6.0, 6.0 + reach), steel_mid)
	draw_rect(Rect2(0.0, -22.0 + reach, ts.x, 8.0), steel_dark)
	draw_rect(Rect2(0.0, -22.0 + reach, ts.x, 2.5), Color(0.72, 0.75, 0.82))


func _draw_clamp() -> void:
	var ts := TRIGGER_SIZE
	var ext := _extension()
	var iron := Color(0.42, 0.36, 0.30)
	var iron_hi := Color(0.62, 0.55, 0.45)
	# Base plate flush with the ground.
	draw_rect(Rect2(-2.0, ts.y - 3.0, ts.x + 4.0, 3.0), iron)
	# Two toothed jaws hinged at the plate edges, closing toward the middle.
	var ang: float = lerpf(0.9, 0.05, ext)   # radians from vertical
	for side in [-1.0, 1.0]:
		var hinge := Vector2(ts.x * 0.5 + side * ts.x * 0.5, ts.y - 3.0)
		var tip := hinge + Vector2(-side * sin(ang) * 0.0 - side * sin(ang) * 20.0, -cos(ang) * 20.0)
		var mid := hinge + Vector2(-side * sin(ang) * 9.0, -cos(ang) * 9.0)
		draw_colored_polygon(PackedVector2Array([
			hinge, tip, mid + Vector2(-side * 4.0, 0.0)]), iron)
		draw_line(hinge, tip, iron_hi, 1.5)
		# Teeth along the jaw.
		for k in range(1, 4):
			var t := hinge.lerp(tip, float(k) / 4.0)
			draw_line(t, t + Vector2(side * 3.0, -1.5), iron_hi, 1.2)
