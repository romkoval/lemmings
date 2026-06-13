class_name LemmingSprite
extends Node2D

# Detailed lemming rendered from baked illustration frames
# (assets/characters/lemming/frames/), one (or two) per game state. Drop-in
# replacement for the old procedural sprite: same `state` / `dir` API, feet on
# the local origin, and the node's `modulate` is never touched so the parent
# Lemming can highlight / bomb-flash it. Animation runs on AnimatedSprite2D's
# own visual clock — never the fixed sim tick, so replays stay deterministic.
#
# The reference art (assets/characters/lemming/ref/) was sliced and normalised
# by tools/slice_character.py: each pose is scaled to a common body height and
# dropped on a shared canvas with the soles on a fixed baseline. This adapter
# just plays the result.
#
# Authored facing right; dir < 0 mirrors horizontally about the feet (origin),
# so the soles stay pinned while the body flips.

const FRAME_DIR := "res://assets/characters/lemming/frames/"
const SS := 4                       # supersample the frames were baked at
const FEET := Vector2(32, 94)       # feet anchor inside the logical canvas (px)
const DISPLAY := 0.2                # texture px -> game px (body ≈ 24 px tall)

# Clip playback (fps + loop). Frame textures are discovered on disk
# (clip_0.png, clip_1.png, …) so animation length is data-driven: `walk` is a
# long baked run cycle (tools/slice_character.py SEQUENCES); the rest are single
# expressive poses sliced from the AI art (see docs/CHARACTER_SPEC.md).
const CLIP_INFO := {
	"walk":  {"fps": 16, "loop": true},
	"fall":  {"fps": 6,  "loop": true},
	"float": {"fps": 6,  "loop": true},
	"climb": {"fps": 6,  "loop": true},
	"block": {"fps": 6,  "loop": true},
	"build": {"fps": 6,  "loop": true},
	"bash":  {"fps": 6,  "loop": true},
	"mine":  {"fps": 6,  "loop": true},
	"dig":   {"fps": 6,  "loop": true},
	"panic": {"fps": 6,  "loop": true},
	"cheer": {"fps": 6,  "loop": false},
	"splat": {"fps": 6,  "loop": false},
}
# Lemming.State (int) -> clip. DYING and SPLAT share the splat pose.
const STATE_TO_CLIP := {
	0: "walk", 1: "fall", 2: "float", 3: "climb", 4: "block", 5: "build",
	6: "bash", 7: "mine", 8: "dig", 9: "panic", 10: "splat", 11: "cheer", 12: "splat",
}

# Built once, shared by every lemming (one texture set in VRAM, cheap instances).
static var _frames: SpriteFrames = null

var state: int = 0:
	set(v):
		state = v
		_apply()
var dir: int = 1:
	set(v):
		dir = v
		_apply()

var _anim: AnimatedSprite2D = null


func _ready() -> void:
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = shared_frames()
	_anim.centered = false
	_anim.offset = -FEET * float(SS)   # pin the feet pixel to the origin
	_anim.scale = Vector2(DISPLAY, DISPLAY)
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_anim)
	_apply()


func _apply() -> void:
	if _anim == null:
		return
	var clip: String = STATE_TO_CLIP.get(state, "walk")
	if _anim.animation != clip or not _anim.is_playing():
		_anim.play(clip)
	# dir = -1 mirrors about the feet (origin); the soles stay put.
	_anim.scale.x = DISPLAY * (1.0 if dir >= 0 else -1.0)


# Assembles the shared SpriteFrames from the baked PNGs on first use.
static func shared_frames() -> SpriteFrames:
	if _frames != null:
		return _frames
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for clip in CLIP_INFO:
		sf.add_animation(clip)
		sf.set_animation_loop(clip, bool(CLIP_INFO[clip]["loop"]))
		sf.set_animation_speed(clip, float(CLIP_INFO[clip]["fps"]))
		# Frames are discovered on disk: clip_0.png, clip_1.png, … until missing.
		var i := 0
		while true:
			var path: String = FRAME_DIR + str(clip) + "_%d.png" % i
			if not ResourceLoader.exists(path):
				break
			sf.add_frame(clip, load(path))
			i += 1
	_frames = sf
	return _frames
