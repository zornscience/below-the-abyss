class_name RiftStalkerProfile
extends PredatorProfile
@export var sense_radius: float = 450.0
@export var scare_radius: float = 240.0
@export var stun_seconds: float = 1.5
@export var flee_seconds: float = 5.0
@export var flee_speed: float = 190.0
@export var contact_interval: float = 3.0
@export var passive_emission: AcousticEmissionProfile = AcousticEmissionProfile.new()
func is_valid() -> bool:
	if not super.is_valid(): return false
	for value: float in [sense_radius,scare_radius,stun_seconds,flee_seconds,flee_speed,contact_interval]:
		if not is_finite(value) or value<=0: return false
	return passive_emission!=null and passive_emission.is_valid() and passive_emission.event_type==&"ambient" and stun_seconds>=0.5 and scare_radius<sense_radius and flee_speed<240
