extends Camera2D

# NOTE: intentionally no `class_name` — game.gd references this script via
# preload() instead, so the level scene never depends on the global script-class
# cache being up to date (a stale cache used to break the whole game scene with
# `Could not find type "GameCamera"`).

# Player-controllable camera for the level view.
#
# The world is rendered at 16×16 tiles which, on a phone, is tiny — so we zoom
# IN by default (Camera2D zoom > 1 magnifies) and let the player pinch / wheel to
# adjust and drag to pan around the level. Movement is clamped so the view never
# leaves the terrain bounds.

const MIN_ZOOM: float = 1.0      # fully zoomed out (see more of the level)
const MAX_ZOOM: float = 4.0      # close-up
const DEFAULT_ZOOM: float = 2.0  # comfortable default — details are readable
const ZOOM_STEP: float = 1.25    # multiplier per button press / wheel notch

# Level extent in world pixels; the view is kept inside this. Defaults to the
# base viewport until setup_bounds() is called with the real terrain rect.
var _bounds: Rect2 = Rect2(0, 0, 720, 1280)

# Base (design) viewport size — independent of device pixels / stretch, so the
# clamp math is deterministic across screens.
var _base_view: Vector2 = Vector2(
	float(ProjectSettings.get_setting("display/window/size/viewport_width", 720)),
	float(ProjectSettings.get_setting("display/window/size/viewport_height", 1280)),
)


func _ready() -> void:
	zoom = Vector2(DEFAULT_ZOOM, DEFAULT_ZOOM)


# Constrain the camera to the level's terrain and centre it on `focus`
# (typically the entrance) so the action is on-screen at the start.
func setup_bounds(bounds_px: Rect2, focus: Vector2 = Vector2.INF) -> void:
	if bounds_px.has_area():
		_bounds = bounds_px
	if focus != Vector2.INF:
		position = focus
	else:
		position = _bounds.get_center()
	_clamp()


# Pan by a drag measured in screen pixels (divide by zoom → world pixels).
func pan_screen(delta_screen: Vector2) -> void:
	position -= delta_screen / zoom
	_clamp()


# Jump the camera so it centres on a world point (clamped to bounds). Used by the
# minimap tap-to-navigate.
func center_on(world_pos: Vector2) -> void:
	position = world_pos
	_clamp()


# Current visible rectangle in world space — drawn as the viewport box on the
# minimap so the player can see where they're looking.
func visible_world_rect() -> Rect2:
	var view: Vector2 = _base_view / zoom
	return Rect2(position - view * 0.5, view)


# Set an absolute zoom level (clamped), keeping the view centred. Used by pinch.
func set_zoom_level(z: float) -> void:
	var nz: float = clampf(z, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(nz, nz)
	_clamp()


# Multiply the current zoom (e.g. button press / wheel). step > 1 zooms in.
func zoom_by(step: float) -> void:
	set_zoom_level(zoom.x * step)


func zoom_in() -> void:
	zoom_by(ZOOM_STEP)


func zoom_out() -> void:
	zoom_by(1.0 / ZOOM_STEP)


# Keep the visible rectangle inside _bounds. On an axis where the level is
# smaller than the view, centre on that axis instead of clamping.
func _clamp() -> void:
	var half: Vector2 = (_base_view * 0.5) / zoom
	var min_x: float = _bounds.position.x + half.x
	var max_x: float = _bounds.end.x - half.x
	if min_x > max_x:
		position.x = _bounds.get_center().x
	else:
		position.x = clampf(position.x, min_x, max_x)
	var min_y: float = _bounds.position.y + half.y
	var max_y: float = _bounds.end.y - half.y
	if min_y > max_y:
		position.y = _bounds.get_center().y
	else:
		position.y = clampf(position.y, min_y, max_y)
