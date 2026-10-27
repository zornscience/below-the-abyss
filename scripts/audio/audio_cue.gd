class_name AudioCue
extends Resource
## Presentation-only identifier; never a gameplay AcousticEvent.

@export var cue_id: StringName
@export var stream: AudioStream
@export_enum("Effects", "UI") var bus: String = "Effects"
@export_range(-50.0, 0.0) var gain_db: float = -10.0
@export_range(0.0, 30.0) var minimum_interval: float = 0.2
@export_range(1, 4) var maximum_voices: int = 1


func is_valid() -> bool:
	return AcousticEvent.valid_token(cue_id) and bus in ["Effects", "UI"] \
		and is_finite(gain_db) and gain_db >= -50.0 and gain_db <= 0.0 \
		and is_finite(minimum_interval) and minimum_interval >= 0.0 and minimum_interval <= 30.0 \
		and maximum_voices >= 1 and maximum_voices <= 4
