extends Node

const SOUNDS_PATH: String = "res://assets/sounds/"
const MUSIC_PATH: String = "res://assets/music/"

var sfx_players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var sound_cache: Dictionary = {}

const SFX_POOL_SIZE: int = 8


func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	add_child(music_player)
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)


func play_sfx(sound_name: String) -> void:
	var stream: AudioStream = _load_sound(sound_name)
	if stream == null:
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = linear_to_db(SaveManager.settings.get("sfx_volume", 1.0))
			p.play()
			return


func play_music(track_name: String) -> void:
	var path: String = _resolve(MUSIC_PATH + track_name)
	if path == "":
		return
	var stream: AudioStream = load(path)
	# Loop background music (placeholder WAVs aren't flagged to loop on import).
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2  # 16-bit mono → 2 bytes/sample
	music_player.stream = stream
	music_player.volume_db = linear_to_db(SaveManager.settings.get("music_volume", 0.8))
	music_player.play()


func stop_music() -> void:
	music_player.stop()


func _load_sound(sound_name: String) -> AudioStream:
	if sound_cache.has(sound_name):
		return sound_cache[sound_name]
	var path: String = _resolve(SOUNDS_PATH + sound_name)
	if path == "":
		return null
	var stream: AudioStream = load(path)
	sound_cache[sound_name] = stream
	return stream


# Resolve an asset path without extension, preferring a real .ogg over the
# generated .wav placeholder. Returns "" if neither exists.
func _resolve(base: String) -> String:
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(base + ext):
			return base + ext
	return ""
