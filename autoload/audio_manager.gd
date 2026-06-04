extends Node

const SOUNDS_PATH: String = "res://assets/sounds/"
const MUSIC_PATH: String = "res://assets/music/"

var sfx_players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var sound_cache: Dictionary = {}

const SFX_POOL_SIZE: int = 8
const MUSIC_BUS: String = "Music"
const SFX_BUS: String = "SFX"
const MASTER_BUS: String = "Master"
# Volume below this (linear) is treated as silence (-80 dB) — linear_to_db(0)
# is -inf, which some platforms dislike.
const MIN_LINEAR: float = 0.001


func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = MUSIC_BUS
	add_child(music_player)
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		sfx_players.append(p)
	apply_settings()


# Push the saved volume/mute settings onto the audio buses. Call after changing
# any setting (the settings screen does) or on startup.
func apply_settings() -> void:
	set_bus_volume(MUSIC_BUS, float(SaveManager.settings.get("music_volume", 0.8)))
	set_bus_volume(SFX_BUS, float(SaveManager.settings.get("sfx_volume", 1.0)))
	set_muted(bool(SaveManager.settings.get("muted", false)))


func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, MIN_LINEAR)) if linear > MIN_LINEAR else -80.0)


func set_music_volume(linear: float) -> void:
	SaveManager.settings["music_volume"] = linear
	set_bus_volume(MUSIC_BUS, linear)


func set_sfx_volume(linear: float) -> void:
	SaveManager.settings["sfx_volume"] = linear
	set_bus_volume(SFX_BUS, linear)


# Global mute toggles the Master bus, silencing both music and SFX at once.
func set_muted(muted: bool) -> void:
	SaveManager.settings["muted"] = muted
	var idx: int = AudioServer.get_bus_index(MASTER_BUS)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)


func is_muted() -> bool:
	return bool(SaveManager.settings.get("muted", false))


func toggle_mute() -> bool:
	set_muted(not is_muted())
	return is_muted()


func play_sfx(sound_name: String) -> void:
	var stream: AudioStream = _load_sound(sound_name)
	if stream == null:
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = stream
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
