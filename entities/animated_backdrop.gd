class_name AnimatedBackdrop
extends TextureRect

# A looping, full-screen image-sequence backdrop — the inferno's animated lava
# vista, split from a short video into frames (assets/backgrounds/inferno_anim/).
# Frames are discovered on disk (bg_0.png, bg_1.png, …) and cycled on a visual
# clock; it's purely cosmetic (sits on a -10 CanvasLayer behind the playfield),
# never the fixed sim tick, so replays are unaffected. Stretches to cover the
# viewport at any resolution.

@export var frames_dir: String = ""
@export var fps: float = 12.0

var _frames: Array[Texture2D] = []
var _t: float = 0.0
var _idx: int = -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	load_frames()
	_show(0)


# Discover frames on disk: bg_0.png, bg_1.png, … until one is missing.
func load_frames() -> void:
	_frames.clear()
	if frames_dir == "":
		return
	var i := 0
	while true:
		var path: String = frames_dir.path_join("bg_%d.png" % i)
		if not ResourceLoader.exists(path):
			break
		_frames.append(load(path))
		i += 1


func _process(delta: float) -> void:
	if _frames.size() < 2:
		return
	_t += delta
	_show(int(_t * fps) % _frames.size())


func _show(n: int) -> void:
	if n != _idx and n >= 0 and n < _frames.size():
		_idx = n
		texture = _frames[n]
