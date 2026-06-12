extends "res://addons/gut/test.gd"

# US-5.1: the remade music pack. 17 in-game tunes + the title theme are real
# OGG Vorbis assets; levels pick their tune by level number (wrapping around
# the pack, like the original game), custom ids hash to a stable tune, and
# every stream is flagged to loop.


func after_each() -> void:
	AudioManager.stop_music()


func test_all_pack_tracks_exist_and_are_ogg() -> void:
	var names: Array[String] = ["theme", "inferno"]
	for i in range(1, AudioManager.LEVEL_TRACKS + 1):
		names.append("remake_%02d" % i)
	for n in names:
		var path: String = "res://assets/music/%s.ogg" % n
		assert_true(ResourceLoader.exists(path), "%s exists" % path)
		var stream: AudioStream = load(path)
		assert_true(stream is AudioStreamOggVorbis, "%s is OGG Vorbis" % n)
		assert_between(stream.get_length(), 30.0, 130.0,
			"%s has a sane duration" % n)


func test_level_music_cycles_by_level_number() -> void:
	AudioManager.play_level_music("fun/level_03")
	assert_true(AudioManager.music_player.stream.resource_path.ends_with("remake_03.ogg"),
		"level 3 gets tune 3")
	AudioManager.play_level_music("tricky/level_10")
	assert_true(AudioManager.music_player.stream.resource_path.ends_with("remake_10.ogg"),
		"rank doesn't matter, the number does")
	# Past the pack size the tunes wrap around.
	AudioManager.play_level_music("mayhem/level_18")
	assert_true(AudioManager.music_player.stream.resource_path.ends_with("remake_01.ogg"),
		"level 18 wraps to tune 1")


func test_custom_level_id_gets_a_stable_tune() -> void:
	AudioManager.play_level_music("my fancy level")
	var first: String = AudioManager.music_player.stream.resource_path
	assert_string_starts_with(first.get_file(), "remake_")
	AudioManager.stop_music()
	AudioManager.play_level_music("my fancy level")
	assert_eq(AudioManager.music_player.stream.resource_path, first,
		"same id → same tune")


func test_music_loops_and_restart_does_not_retrigger() -> void:
	AudioManager.play_level_music("fun/level_01")
	var stream: AudioStream = AudioManager.music_player.stream
	assert_true((stream as AudioStreamOggVorbis).loop, "pack tunes loop")
	# A level restart re-requests the same track — the stream must not be
	# swapped out (that would audibly restart the tune).
	AudioManager.play_level_music("fun/level_01")
	assert_eq(AudioManager.music_player.stream, stream, "same stream object kept")


func test_menu_theme_prefers_the_ogg_remake() -> void:
	AudioManager.play_music("theme")
	assert_true(AudioManager.music_player.stream is AudioStreamOggVorbis,
		"theme.ogg outranks the placeholder theme.wav")


func test_level_can_pin_a_named_track() -> void:
	# Themed levels (e.g. the hell set) pin their tune via "music" in the JSON
	# instead of taking the rotation pick.
	var data: Dictionary = {
		"id": "_gut_music_level", "name": "music gut", "custom": true,
		"total_lemmings": 1, "save_required": 1, "time_limit": 120, "release_rate": 50,
		"skill_counts": {"climber": 0, "floater": 0, "bomber": 0, "blocker": 0,
			"builder": 0, "basher": 0, "miner": 0, "digger": 1},
		"entrance_pos": [80, 398], "entrance_direction": 1, "exit_pos": [620, 446],
		"terrain_rects": [{"x": 0, "y": 29, "w": 45, "h": 4}],
		"music": "inferno",
	}
	var path: String = "user://custom_levels/_gut_music_level.json"
	LevelManager.save_level_json(path, data)
	var game: Game = (load("res://scenes/game/game.tscn") as PackedScene).instantiate() as Game
	game.initial_level_path = path
	add_child_autoqfree(game)
	await wait_physics_frames(2)
	assert_true(AudioManager.music_player.stream.resource_path.ends_with("inferno.ogg"),
		"level override wins over the rotation")
	LevelManager.delete_custom_level(path)
	GameManager.reset()
