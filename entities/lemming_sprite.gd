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
const FEET := Vector2(28, 80)       # feet anchor inside the logical canvas (px)
const DISPLAY := 0.2                # texture px -> game px (body ≈ 24 px tall)

# Clip name -> frame basenames (no extension). `walk` is a 2-frame shuffle; the
# rest are single expressive poses — the source art isn't frame-consistent
# enough for smooth multi-frame cycles (see docs/CHARACTER_SPEC.md).
const CLIPS := {
	"walk":  ["walk_0", "walk_1"],
	"fall":  ["fall_0"],
	"float": ["float_0"],
	"climb": ["climb_0"],
	"block": ["block_0"],
	"build": ["build_0"],
	"bash":  ["bash_0"],
	"mine":  ["mine_0"],
	"dig":   ["dig_0"],
	"panic": ["panic_0"],
	"cheer": ["cheer_0"],
	"splat": ["splat_0"],
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
	for clip in CLIPS:
		sf.add_animation(clip)
		sf.set_animation_loop(clip, clip != "splat" and clip != "cheer")
		sf.set_animation_speed(clip, 8.0 if clip == "walk" else 6.0)
		for base in CLIPS[clip]:
			var tex: Texture2D = load(FRAME_DIR + base + ".png")
			if tex != null:
				sf.add_frame(clip, tex)
	_frames = sf
	return _frames
