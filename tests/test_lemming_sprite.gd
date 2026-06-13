extends "res://addons/gut/test.gd"

# US-5.6: the lemming is rendered from baked illustration frames via a drop-in
# AnimatedSprite2D adapter. These guard the integration contract the game logic
# (entities/lemming.gd), menus and world map all depend on: the state/dir API,
# the feet-on-origin anchor, mirroring, and that the adapter never clobbers the
# node modulate the parent uses for highlight / bomb-flash.

const SpriteScript: Script = preload("res://entities/lemming_sprite.gd")


func _sprite() -> LemmingSprite:
	var s := LemmingSprite.new()
	add_child_autoqfree(s)
	return s


func test_state_and_dir_are_settable_ints() -> void:
	var s := _sprite()
	await wait_frames(1)
	s.state = Lemming.State.DIGGING
	s.dir = -1
	assert_eq(s.state, int(Lemming.State.DIGGING))
	assert_eq(s.dir, -1)


func test_every_lemming_state_maps_to_a_real_clip() -> void:
	var frames: SpriteFrames = LemmingSprite.shared_frames()
	for st in Lemming.State.values():
		assert_true(SpriteScript.STATE_TO_CLIP.has(int(st)),
			"state %d has a clip mapping" % st)
		var clip: String = SpriteScript.STATE_TO_CLIP[int(st)]
		assert_true(frames.has_animation(clip), "clip '%s' exists in SpriteFrames" % clip)


func test_every_clip_has_at_least_one_frame() -> void:
	var frames: SpriteFrames = LemmingSprite.shared_frames()
	for clip in SpriteScript.CLIPS:
		assert_true(frames.has_animation(clip), "animation '%s' built" % clip)
		assert_gt(frames.get_frame_count(clip), 0, "clip '%s' has frames" % clip)
	assert_eq(frames.get_frame_count("walk"), 2, "walk is a 2-frame shuffle")
	assert_false(frames.get_animation_loop("splat"), "splat does not loop")


func test_feet_sit_on_the_local_origin() -> void:
	var s := _sprite()
	await wait_frames(1)
	# The art is anchored so the soles land on the node origin: the child
	# AnimatedSprite2D is top-left aligned with offset = -FEET*SS, so feet at (0,0).
	assert_false(s._anim.centered, "top-left aligned, not centred")
	assert_eq(s._anim.offset, -SpriteScript.FEET * float(SpriteScript.SS),
		"feet pixel pinned to the origin")


func test_dir_mirrors_about_the_feet_without_moving_the_node() -> void:
	var s := _sprite()
	await wait_frames(1)
	var pos0: Vector2 = s.position
	s.dir = 1
	assert_gt(s._anim.scale.x, 0.0, "facing right = positive x scale")
	s.dir = -1
	assert_lt(s._anim.scale.x, 0.0, "facing left = mirrored x scale")
	assert_eq(s.position, pos0, "mirroring never shifts the node position")


func test_adapter_leaves_node_modulate_alone() -> void:
	# The parent Lemming drives modulate (highlight 1.7/1.7/0.7, bomb flash). The
	# sprite must never overwrite it.
	var s := _sprite()
	await wait_frames(1)
	s.state = Lemming.State.WALKING
	s.dir = -1
	s.state = Lemming.State.EXPLODING
	assert_eq(s.modulate, Color(1, 1, 1, 1), "adapter keeps modulate untouched")


func test_works_standalone_without_a_lemming_parent() -> void:
	# Menus and the world-map avatar use LemmingSprite on its own.
	var s := _sprite()
	s.state = Lemming.State.WALKING
	await wait_frames(2)
	assert_not_null(s._anim, "built its AnimatedSprite2D")
	assert_true(s._anim.is_playing(), "animation runs with no game around it")
	assert_eq(s._anim.animation, "walk")
