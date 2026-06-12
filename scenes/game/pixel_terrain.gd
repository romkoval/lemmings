class_name PixelTerrain
extends Sprite2D

# Per-pixel terrain, like the original Lemmings: the landscape is a 1px-resolution
# solidity mask (plus a material id per pixel), NOT a grid of 16px collision
# tiles. Tile layers remain only as the level-authoring format — at level load
# they are rasterized into the mask and hidden. Everything gameplay-side (walking,
# carving, building) queries and edits pixels, and the visible terrain is drawn
# by a shader straight from the same mask, so physics and visuals can never
# disagree.
#
# Mask byte semantics: 0 = air, 255 = solid; smoothing leaves a short gradient
# at edges and SOLID_EPS decides where ground begins. The shader thresholds at
# the same value, with sub-pixel anti-aliasing on top.

const MAT_DIRT: float = 0.0
const MAT_WOOD: float = 0.5
const MAT_STEEL: float = 1.0
# One-way walls (US-1.5): destructible only when worked in the arrow's
# direction (basher/miner). Direction-less carving (digger, explosions) goes
# through. Values sit in their own L8 bands clear of dirt/wood/steel, so the
# byte rounding of a PNG round-trip can never flip a material.
const MAT_ONEWAY_R: float = 0.2    # carvable left-to-right only (dir = +1)
const MAT_ONEWAY_L: float = 0.35   # carvable right-to-left only (dir = -1)
# get_pixel().r >= this counts as solid; ~120/255, slightly below the 0.5
# midpoint so authored straight edges (which smooth to exactly 0.5) stay solid.
const SOLID_EPS: float = 0.47

var _mask: Image                 # L8 solidity, live gameplay truth
var _mat: Image                  # L8 material id (0 dirt / 0.5 wood / 1 steel)
var _mask_tex: ImageTexture
var _mat_tex: ImageTexture
var _origin: Vector2i = Vector2i.ZERO   # world px of mask (0,0)
var _size: Vector2i = Vector2i.ZERO
var _dirty: bool = false


func build_from_tiles(terrain: TileMapLayer, steel: TileMapLayer) -> void:
	var used: Rect2i = terrain.get_used_rect()
	var su: Rect2i = steel.get_used_rect()
	if su.has_area():
		used = su if not used.has_area() else used.merge(su)
	if not used.has_area():
		used = Rect2i(0, 0, 45, 80)
	# Cover the default playfield even for tiny/test levels, and grow generously
	# so builder bridges and test fixtures never fall outside the mask.
	used = used.merge(Rect2i(-8, -12, 64, 104)).grow(12)
	_origin = used.position * Level.TILE_SIZE
	_size = used.size * Level.TILE_SIZE
	_mask = Image.create(_size.x, _size.y, false, Image.FORMAT_L8)
	_mat = Image.create(_size.x, _size.y, false, Image.FORMAT_L8)

	for cell: Vector2i in terrain.get_used_cells():
		var local: Vector2i = cell * Level.TILE_SIZE - _origin
		var atlas: Vector2i = terrain.get_cell_atlas_coords(cell)
		if atlas.y == 1:
			# 45° ramp cells: (0,1)/(2,1) rise to the right, (1,1)/(3,1) to the left.
			var right_rise: bool = (atlas.x % 2) == 0
			for y in range(Level.TILE_SIZE):
				for x in range(Level.TILE_SIZE):
					var inside: bool = (x + y >= Level.TILE_SIZE - 1) if right_rise else (y >= x)
					if inside:
						_mask.set_pixel(local.x + x, local.y + y, Color.WHITE)
		else:
			_mask.fill_rect(Rect2i(local, Vector2i(Level.TILE_SIZE, Level.TILE_SIZE)), Color.WHITE)

	_smooth_mask()

	# Steel is stamped AFTER smoothing: plates keep hard machined edges and the
	# exact authored footprint (they are indestructible, so the mask must never
	# erode them).
	for cell: Vector2i in steel.get_used_cells():
		var local: Vector2i = cell * Level.TILE_SIZE - _origin
		var r := Rect2i(local, Vector2i(Level.TILE_SIZE, Level.TILE_SIZE))
		_mask.fill_rect(r, Color.WHITE)
		_mat.fill_rect(r, Color.WHITE)

	_finalize_build()


# Build straight from previously saved mask/material images (the level editor's
# format — painted in pixel space, so NO smoothing: what was painted is exactly
# what plays).
func build_from_images(mask_img: Image, mat_img: Image, origin: Vector2i) -> void:
	_origin = origin
	_mask = mask_img
	if _mask.get_format() != Image.FORMAT_L8:
		_mask.convert(Image.FORMAT_L8)
	_size = Vector2i(_mask.get_width(), _mask.get_height())
	if mat_img != null and mat_img.get_width() == _size.x and mat_img.get_height() == _size.y:
		_mat = mat_img
		if _mat.get_format() != Image.FORMAT_L8:
			_mat.convert(Image.FORMAT_L8)
	else:
		_mat = Image.create(_size.x, _size.y, false, Image.FORMAT_L8)
	_finalize_build()


# An all-air canvas covering `rect_px` (world pixels) plus a working margin for
# builder bridges. Used by the level editor for fresh canvases of any size.
func build_blank(rect_px: Rect2i, margin: int = 192) -> void:
	_origin = rect_px.position - Vector2i(margin, margin)
	_size = rect_px.size + Vector2i(margin * 2, margin * 2)
	_mask = Image.create(_size.x, _size.y, false, Image.FORMAT_L8)
	_mat = Image.create(_size.x, _size.y, false, Image.FORMAT_L8)
	_finalize_build()


# Copy previously exported content into the current canvas (level editor canvas
# resize): pixels keep their world position; anything outside is cropped.
func blit_from(mask_img: Image, mat_img: Image, src_origin: Vector2i) -> void:
	var src_rect := Rect2i(Vector2i.ZERO, Vector2i(mask_img.get_width(), mask_img.get_height()))
	var dst: Vector2i = src_origin - _origin
	_mask.blit_rect(mask_img, src_rect, dst)
	if mat_img != null:
		_mat.blit_rect(mat_img, src_rect, dst)
	_dirty = true


# Copies of the live mask/material for saving (level editor).
func export_images() -> Dictionary:
	return {
		"mask": _mask.duplicate(),
		"mat": _mat.duplicate(),
		"origin": _origin,
	}


# In the editor the canvas is being authored, so grass follows the strokes live
# (the "original surface" IS the current one). In the game it must be the
# load-time snapshot, so carved tunnels expose bare dirt. Set before build.
var live_grass: bool = false


func _finalize_build() -> void:
	_mask_tex = ImageTexture.create_from_image(_mask)
	_mat_tex = ImageTexture.create_from_image(_mat)
	texture = _mask_tex
	centered = false
	position = Vector2(_origin)
	# Linear filtering gives the shader sub-pixel anti-aliased edges; the
	# gameplay mask query stays per-pixel.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var sh := ShaderMaterial.new()
	sh.shader = load("res://assets/shaders/pixel_terrain.gdshader")
	sh.set_shader_parameter("material_tex", _mat_tex)
	# Grass grows only where the ORIGINAL surface was: a frozen snapshot of the
	# load-time mask. Skills carve the live mask; the snapshot never updates, so
	# bashed/mined passages stay bare dirt instead of sprouting grass.
	var orig_tex: ImageTexture = _mask_tex if live_grass else ImageTexture.create_from_image(_mask)
	sh.set_shader_parameter("orig_mask", orig_tex)
	material = sh


# Round off the blocky tile corners so the relief reads as organic ground, not
# a grid of cubes. Two half-res bilinear hops down and back up leave a short
# gradient that rounds corners by ~4-6px while keeping straight edges exactly
# on the authored line (the 0.5 isoline coincides with the tile boundary).
func _smooth_mask() -> void:
	var w := _size.x
	var h := _size.y
	_mask.resize(w >> 1, h >> 1, Image.INTERPOLATE_BILINEAR)
	_mask.resize(w >> 2, h >> 2, Image.INTERPOLATE_BILINEAR)
	_mask.resize(w >> 1, h >> 1, Image.INTERPOLATE_BILINEAR)
	_mask.resize(w, h, Image.INTERPOLATE_BILINEAR)


func _process(_delta: float) -> void:
	# Carves/fills mark the textures dirty; upload at most once per frame.
	if _dirty:
		_dirty = false
		_mask_tex.update(_mask)
		_mat_tex.update(_mat)


func bounds_px() -> Rect2i:
	return Rect2i(_origin, _size)


func _local(wp: Vector2) -> Vector2i:
	return Vector2i(floori(wp.x), floori(wp.y)) - _origin


func is_solid_px(wp: Vector2) -> bool:
	var p := _local(wp)
	if p.x < 0 or p.y < 0 or p.x >= _size.x or p.y >= _size.y:
		return false
	return _mask.get_pixel(p.x, p.y).r >= SOLID_EPS


func is_steel_px(wp: Vector2) -> bool:
	var p := _local(wp)
	if p.x < 0 or p.y < 0 or p.x >= _size.x or p.y >= _size.y:
		return false
	return _mat.get_pixel(p.x, p.y).r > 0.8 and _mask.get_pixel(p.x, p.y).r >= SOLID_EPS


# One-way wall direction at a solid pixel: +1 right-only, -1 left-only, 0 none.
func oneway_dir_px(wp: Vector2) -> int:
	var p := _local(wp)
	if p.x < 0 or p.y < 0 or p.x >= _size.x or p.y >= _size.y:
		return 0
	if _mask.get_pixel(p.x, p.y).r < SOLID_EPS:
		return 0
	return _oneway_dir(_mat.get_pixel(p.x, p.y).r)


static func _oneway_dir(m: float) -> int:
	if m > 0.12 and m < 0.28:
		return 1
	if m >= 0.28 and m < 0.45:
		return -1
	return 0


# Clip a world-px rect to the mask, returning the local rect.
func _clip(r: Rect2i) -> Rect2i:
	return Rect2i(r.position - _origin, r.size).intersection(Rect2i(Vector2i.ZERO, _size))


# Remove destructible pixels in the rect. Steel survives; one-way pixels
# survive a DIRECTIONAL carve (dir = ±1, basher/miner) going against their
# arrow. dir = 0 means direction-less (digger, explosions) — goes through
# one-way walls, classic behaviour. Returns the number of pixels carved.
func carve_rect(r: Rect2i, dir: int = 0) -> int:
	var rr := _clip(r)
	var carved := 0
	for y in range(rr.position.y, rr.end.y):
		for x in range(rr.position.x, rr.end.x):
			if _mask.get_pixel(x, y).r < SOLID_EPS:
				continue
			var m: float = _mat.get_pixel(x, y).r
			if m > 0.8:
				continue
			if dir != 0:
				var ow: int = _oneway_dir(m)
				if ow != 0 and ow != dir:
					continue
			_mask.set_pixel(x, y, Color.BLACK)
			carved += 1
	if carved > 0:
		_dirty = true
	return carved


# True if a directional carve of this rect would hit an impassable pixel:
# steel, or a one-way wall pointing against `dir`. Bashers/miners use it to
# stop swinging, the same way they stop at steel.
func rect_blocks_carve(r: Rect2i, dir: int) -> bool:
	var rr := _clip(r)
	for y in range(rr.position.y, rr.end.y):
		for x in range(rr.position.x, rr.end.x):
			var m: float = _mat.get_pixel(x, y).r
			if m > 0.8:
				return true
			var ow: int = _oneway_dir(m)
			if ow != 0 and ow != dir and _mask.get_pixel(x, y).r >= SOLID_EPS:
				return true
	return false


# `force` (level editor only) erases steel as well.
func carve_circle(center: Vector2, radius: float, force: bool = false) -> int:
	var c := Vector2(center)
	var r := int(ceilf(radius))
	var box := Rect2i(Vector2i(floori(c.x) - r, floori(c.y) - r), Vector2i(r * 2 + 1, r * 2 + 1))
	var rr := _clip(box)
	var carved := 0
	for y in range(rr.position.y, rr.end.y):
		for x in range(rr.position.x, rr.end.x):
			var wp := Vector2(float(x + _origin.x) + 0.5, float(y + _origin.y) + 0.5)
			if wp.distance_to(c) > radius:
				continue
			if _mask.get_pixel(x, y).r < SOLID_EPS:
				continue
			if not force and _mat.get_pixel(x, y).r > 0.8:
				continue
			_mask.set_pixel(x, y, Color.BLACK)
			if force:
				_mat.set_pixel(x, y, Color.BLACK)
			carved += 1
	if carved > 0:
		_dirty = true
	return carved


# Add solid pixels (builder planks, test fixtures). Never overwrites steel
# unless `force` (level editor painting over a steel area).
func fill_rect(r: Rect2i, mat: float = MAT_DIRT, force: bool = false) -> void:
	var rr := _clip(r)
	if not rr.has_area():
		return
	for y in range(rr.position.y, rr.end.y):
		for x in range(rr.position.x, rr.end.x):
			if not force and _mat.get_pixel(x, y).r > 0.8:
				continue
			_mask.set_pixel(x, y, Color.WHITE)
			_mat.set_pixel(x, y, Color(mat, mat, mat))
	_dirty = true


# Round brush stamp for the level editor.
func fill_circle(center: Vector2, radius: float, mat: float = MAT_DIRT, force: bool = false) -> void:
	var c := Vector2(center)
	var r := int(ceilf(radius))
	var box := Rect2i(Vector2i(floori(c.x) - r, floori(c.y) - r), Vector2i(r * 2 + 1, r * 2 + 1))
	var rr := _clip(box)
	for y in range(rr.position.y, rr.end.y):
		for x in range(rr.position.x, rr.end.x):
			var wp := Vector2(float(x + _origin.x) + 0.5, float(y + _origin.y) + 0.5)
			if wp.distance_to(c) > radius:
				continue
			if not force and _mat.get_pixel(x, y).r > 0.8:
				continue
			_mask.set_pixel(x, y, Color.WHITE)
			_mat.set_pixel(x, y, Color(mat, mat, mat))
	_dirty = true


func rect_has_steel(r: Rect2i) -> bool:
	var rr := _clip(r)
	for y in range(rr.position.y, rr.end.y):
		for x in range(rr.position.x, rr.end.x):
			if _mat.get_pixel(x, y).r > 0.8:
				return true
	return false
