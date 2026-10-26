class_name SoundscapeProfile
extends Resource

@export var cues: Array[AudioCue] = []
@export_range(1, 16) var maximum_voices: int = 10
@export_range(0.05, 5.0) var fade_seconds: float = 0.8
@export_range(0.0, 1.0) var low_resource_fraction: float = 0.2
@export_range(1.0, 1000.0) var deep_mix_meters: float = 350.0
@export_range(0.1, 10.0) var duck_seconds: float = 1.2
@export_range(0.0, 1.0) var duck_gain: float = 0.65


func is_valid() -> bool:
	if maximum_voices < 1 or maximum_voices > 16 or not is_finite(fade_seconds) or fade_seconds <= 0.0 \
		or not is_finite(low_resource_fraction) or low_resource_fraction < 0.0 or low_resource_fraction > 1.0 \
		or not is_finite(deep_mix_meters) or deep_mix_meters <= 0.0 \
		or not is_finite(duck_seconds) or duck_seconds <= 0.0 \
		or not is_finite(duck_gain) or duck_gain < 0.0 or duck_gain > 1.0 or cues.size() > 64:
		return false
	var seen: Dictionary[StringName, bool] = {}
	for cue: AudioCue in cues:
		if cue == null or not cue.is_valid() or seen.has(cue.cue_id):
			return false
		seen[cue.cue_id] = true
	return true
