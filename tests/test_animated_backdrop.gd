extends "res://addons/gut/test.gd"

# The inferno's animated background: a looping image sequence (split from a
# video) cycled on a visual clock, stretched to cover the viewport.

const ANIM_DIR := "res://assets/backgrounds/inferno_anim"


func _backdrop() -> AnimatedBackdrop:
	var b := AnimatedBackdrop.new()
	b.frames_dir = ANIM_DIR
	add_child_autoqfree(b)
	return b


func test_loads_a_multi_frame_sequence() -> void:
	var b := _backdrop()
	await wait_physics_frames(1)
	assert_gt(b._frames.size(), 1, "the lava vista is a multi-frame loop")
	assert_not_null(b.texture, "shows a frame once ready")


func test_cycles_and_loops_on_the_visual_clock() -> void:
	var b := _backdrop()
	await wait_physics_frames(1)
	var n: int = b._frames.size()
	# Advance ~ one full loop worth of time: index stays in range and wraps.
	b._t = 0.0
	b._process(0.5 / b.fps)          # ~half a frame in
	var first: int = b._idx
	b._process(3.0 / b.fps)          # a few frames later
	assert_ne(b._idx, first, "the frame advances over time")
	b._t = float(n) / b.fps + 0.001  # just past one full loop
	b._process(0.0)
	assert_true(b._idx >= 0 and b._idx < n, "index wraps within the sequence")


func test_covers_the_viewport_behind_the_playfield() -> void:
	var b := _backdrop()
	await wait_physics_frames(1)
	assert_eq(b.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED, "fills the screen")
	assert_eq(b.mouse_filter, Control.MOUSE_FILTER_IGNORE, "never eats input")
