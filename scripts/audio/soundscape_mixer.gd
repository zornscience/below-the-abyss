class_name SoundscapeMixer
extends Node
## Scene-owned, bounded presentation. Has no bus emitter/receiver or gameplay writer.

signal cue_played(cue_id: StringName, bus: String)
const BUSES: Array[String] = ["Master", "Music", "Ambience", "Effects", "UI"]
const ALARMS: Array[StringName] = [&"hull", &"oxygen", &"battery", &"predator_alert", &"predator_pursue"]
const LOOP_NAMES: Array[String] = ["ocean", "current", "engine", "tension", "scan", "sunlit_music"]
@export var configuration: SoundscapeProfile = preload("res://resources/audio/shelf_soundscape.tres")
var _rules: SoundscapeProfile
var _cues: Dictionary[StringName, AudioCue] = {}
var _players: Array[AudioStreamPlayer] = []
var _loops: Dictionary[String, AudioStreamPlayer] = {}
var _cooldowns: Dictionary[StringName, float] = {}
var _audio: Dictionary = SettingsStore.default_audio()
var _duck: float = 0.0
var _running: bool = false
var _depth: float = 0.0
var _thrust: float = 0.0
var _pressure: bool = false
var _threat: float = 0.0
var _scanning: bool = false
var _audible_output: bool = false
var _settings: SettingsStore


func _ready() -> void:
	if configuration == null or not configuration.is_valid():
		push_error("Invalid soundscape profile.")
		return
	# Headless CI validates requests/routing without creating Dummy-driver playbacks.
	_audible_output = DisplayServer.get_name() != "headless"
	_rules = configuration.duplicate(true) as SoundscapeProfile
	for cue: AudioCue in _rules.cues:
		_cues[cue.cue_id] = cue
	for _index: int in range(_rules.maximum_voices):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	for id: String in LOOP_NAMES:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		var path: String = "res://assets/audio/%s.wav" % id
		if not ResourceLoader.exists(path):
			player.free()
			continue
		player.stream = load(path) as AudioStream
		player.bus = "Music" if id=="sunlit_music" else ("Ambience" if id in ["ocean", "current", "tension"] else "Effects")
		player.volume_linear = 0.0
		add_child(player)
		_loops[id] = player
		if _audible_output:
			player.play()


func bind_settings(settings: SettingsStore) -> void:
	if _settings != null and _settings.settings_changed.is_connected(_refresh_settings):
		_settings.settings_changed.disconnect(_refresh_settings)
	_settings = settings
	if settings != null:
		settings.settings_changed.connect(_refresh_settings)
		_refresh_settings()


func _refresh_settings() -> void:
	apply_audio(_settings.snapshot().audio)


func apply_audio(audio: Dictionary) -> Error:
	if not SettingsStore.valid_audio(audio):
		return ERR_INVALID_PARAMETER
	_audio = audio.duplicate(true)
	for bus: String in BUSES:
		var index: int = AudioServer.get_bus_index(bus)
		if index < 0:
			return ERR_UNCONFIGURED
		AudioServer.set_bus_volume_linear(index, float(audio[bus]))
		AudioServer.set_bus_mute(index, bool(audio.muted) if bus == "Master" else float(audio[bus]) == 0.0)
	if bool(audio.muted) or float(audio.Master) == 0.0:
		stop_cues()
	return OK


func request(cue_id: StringName) -> bool:
	var cue: AudioCue = _cues.get(cue_id)
	if cue == null or cue.stream == null or not cue.is_valid() or _cooldowns.get(cue_id, 0.0) > 0.0 \
		or bool(_audio.muted) or float(_audio.Master) == 0.0 or float(_audio[cue.bus]) == 0.0:
		return false
	var length: float = cue.stream.get_length()
	if not is_finite(length) or length <= 0.0:
		return false
	var count: int = 0
	var free_player: AudioStreamPlayer
	for player: AudioStreamPlayer in _players:
		if cue_id in ALARMS and float(player.get_meta("remaining", 0.0)) > 0.0 and player.get_meta("cue_id", &"") in ALARMS:
			return false
		if float(player.get_meta("remaining", 0.0)) > 0.0 and player.get_meta("cue_id", &"") == cue_id:
			count += 1
		elif float(player.get_meta("remaining", 0.0)) <= 0.0 and free_player == null:
			free_player = player
	if count >= cue.maximum_voices or free_player == null:
		return false
	free_player.stream = cue.stream
	free_player.bus = cue.bus
	free_player.volume_db = cue.gain_db
	free_player.set_meta("cue_id", cue_id)
	free_player.set_meta("remaining", length)
	if _audible_output:
		free_player.play()
	_cooldowns[cue_id] = cue.minimum_interval
	if cue_id in [&"ping", &"echo", &"complete", &"predator_alert", &"predator_pursue"]:
		_duck = _rules.duck_seconds
	cue_played.emit(cue_id, cue.bus)
	return true


func stop_cues() -> void:
	for player: AudioStreamPlayer in _players:
		player.stop()
		player.set_meta("remaining", 0.0)


func reset_session() -> void:
	stop_cues()
	_cooldowns.clear()
	_duck = 0.0
	_scanning = false
	_threat = 0.0
	# Continuous ocean phase and preferences intentionally survive route restart.


func set_context(running: bool, depth: float, thrust: float, pressure: bool, threat: float, scanning: bool) -> void:
	_running = running
	_depth = clampf(depth, 0.0, 10000.0) if is_finite(depth) else 0.0
	_thrust = clampf(thrust, 0.0, 1.0) if is_finite(thrust) else 0.0
	_pressure = pressure
	_threat = clampf(threat, 0.0, 1.0) if is_finite(threat) else 0.0
	_scanning = scanning


func advance(delta: float) -> void:
	if _rules == null or not is_finite(delta) or delta < 0.0:
		return
	for player: AudioStreamPlayer in _players:
		player.set_meta("remaining", maxf(0.0, float(player.get_meta("remaining", 0.0)) - delta))
	for id: StringName in _cooldowns:
		_cooldowns[id] = maxf(0.0, _cooldowns[id] - delta)
	_duck = maxf(0.0, _duck - delta)
	var deep: float = clampf(_depth / _rules.deep_mix_meters, 0.0, 1.0)
	var duck: float = _rules.duck_gain if _duck > 0.0 else 1.0
	var menu: float = 1.0 if _running else 0.35
	var targets: Dictionary = {
		"ocean": lerpf(0.22, 0.4, deep) * menu * duck,
		"current": lerpf(0.28, 0.06, deep) * menu * duck,
		"engine": (0.18 + _thrust * 0.45) if _running else 0.0,
		"tension": (_threat * 0.5 + (0.12 if _pressure else 0.0)) * menu * duck,
		"scan": 0.3 if _running and _scanning else 0.0,
		"sunlit_music": 0.18 * menu * duck,
	}
	var weight: float = 1.0 - exp(-delta / _rules.fade_seconds)
	for id: String in _loops:
		var player: AudioStreamPlayer = _loops[id]
		player.volume_linear = lerpf(player.volume_linear, float(targets[id]), weight)
		if id == "engine":
			player.pitch_scale = lerpf(player.pitch_scale, 0.85 + _thrust * 0.3, weight)


func _process(delta: float) -> void:
	advance(delta)


func active_voice_count() -> int:
	var count: int = 0
	for player: AudioStreamPlayer in _players:
		if float(player.get_meta("remaining", 0.0)) > 0.0:
			count += 1
	return count


func _exit_tree() -> void:
	for player: AudioStreamPlayer in _players:
		player.stop()
		player.stream = null
	for player: AudioStreamPlayer in _loops.values():
		player.stop()
		player.stream = null
	if _settings != null and _settings.settings_changed.is_connected(_refresh_settings):
		_settings.settings_changed.disconnect(_refresh_settings)
