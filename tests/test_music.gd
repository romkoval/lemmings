extends "res://addons/gut/test.gd"

# US-5.1: the remade music pack. 17 in-game tunes + the title theme are real
# OGG Vorbis assets; levels pick their tune by level number (wrapping around
# the pack, like the original game), custom ids hash to a stable tune, and
# every stream is flagged to loop.


func after_each() -> void:
	AudioManager.stop_music()


func test_all_pack_tracks_exist_and_are_ogg() -> void:
	var names: Array[String] = ["theme"]
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
