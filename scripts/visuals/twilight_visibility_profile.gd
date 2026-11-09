class_name TwilightVisibilityProfile
extends Resource
## Phase-one presentation only. No discovery or checkpoint data.
@export_range(0.0,1.0) var ambient: float = 0.16
@export_range(0.0,1.0) var reduced_ambient: float = 0.36
@export var passive_radius: float = 95.0
@export var safety_radius: float = 150.0
@export var headlight_range: float = 480.0
@export var cone_half_angle: float = 0.24
@export_range(0.0,1.0) var echo_gain: float = 0.8
@export_range(0.0,1.0) var calm_echo_gain: float = 0.55
@export var reveal_seconds: float = 6.0
func is_valid() -> bool:
	for value: float in [ambient,reduced_ambient,echo_gain,calm_echo_gain,passive_radius,safety_radius,headlight_range,cone_half_angle,reveal_seconds]:
		if not is_finite(value): return false
	return echo_gain>=0 and echo_gain<=1 and calm_echo_gain>=0 and calm_echo_gain<=echo_gain and ambient>=0 and reduced_ambient>=ambient and reduced_ambient<=1 and passive_radius>0 and safety_radius>=passive_radius and headlight_range>=safety_radius and cone_half_angle>0 and cone_half_angle<PI/2 and reveal_seconds>0
static func echo_strength(distance: float, age: float, speed: float, radius: float, duration: float) -> float:
	if not is_finite(distance) or not is_finite(age) or distance<0 or speed<=0 or duration<=0 or distance>radius: return 0
	var since: float = age-distance/speed
	return clampf(1.0-since/duration,0,1) if since>=0 else 0.0
func close_strength(distance: float) -> float:
	return 1.0-smoothstep(passive_radius,safety_radius,distance) if is_finite(distance) else 0.0
