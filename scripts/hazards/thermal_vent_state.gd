class_name ThermalVentState
extends RefCounted
## Exact phase-overlap integration: no wall-clock or render-frame damage/cooldowns.
enum Phase {QUIET, WARNING, ERUPTING, COOLING}
var clock: float = 0.0
var _rules: ThermalVentProfile
func configure(profile: ThermalVentProfile) -> Error:
	if profile==null or not profile.is_valid(): return ERR_INVALID_PARAMETER
	_rules = profile.duplicate(true) as ThermalVentProfile
	reset()
	return OK
func reset() -> void:
	clock = 0.0
func phase() -> Phase:
	if _rules==null: return Phase.QUIET
	if clock<_rules.quiet_seconds: return Phase.QUIET
	if clock<_rules.quiet_seconds+_rules.warning_seconds: return Phase.WARNING
	if clock<_rules.quiet_seconds+_rules.warning_seconds+_rules.erupt_seconds: return Phase.ERUPTING
	return Phase.COOLING
func seconds_to_eruption() -> float:
	if _rules==null: return INF
	return maxf(0.0,_rules.quiet_seconds+_rules.warning_seconds-clock)
func advance(delta: float,exposed: bool) -> float:
	if _rules==null or not is_finite(delta) or delta<0 or delta>1.0: return 0.0
	var beginning: float = _rules.quiet_seconds+_rules.warning_seconds
	var end: float = beginning+_rules.erupt_seconds
	var remaining: float = delta
	var exposure: float = 0.0
	while remaining>0.000000001:
		var step: float = minf(remaining,_rules.cycle_seconds()-clock)
		exposure += maxf(0.0,minf(clock+step,end)-maxf(clock,beginning))
		clock += step
		remaining -= step
		if clock>=_rules.cycle_seconds()-0.000000001: clock = 0.0
	return exposure*_rules.hull_per_second if exposed else 0.0
