class_name LifeSupportCountdown
extends RefCounted
## Session-only life-support grace. Pure rules: the owner advances it with simulation
## time only, so it freezes whenever the simulation is paused. Nothing here is saved.

signal started(grace_seconds: float)
signal critical(remaining: float)
signal cancelled
signal expired

## Seconds remaining at which the critical alarm and visual state begin.
const CRITICAL_SECONDS: float = 10.0
var grace_seconds: float = 60.0
var remaining: float = 0.0
var running: bool = false
var _critical_sent: bool = false
var _expired_sent: bool = false


func configure(profile: VesselRecoveryProfile) -> Error:
	if profile == null or not profile.is_valid():
		return ERR_INVALID_PARAMETER
	grace_seconds = profile.grace_seconds
	reset_session()
	return OK


## Clears all session state. The next zero-oxygen step starts the full grace again.
func reset_session() -> void:
	running = false
	remaining = grace_seconds
	_critical_sent = false
	_expired_sent = false


## Call once per simulation step. Returns true on the single step that expires.
func advance(delta: float, oxygen: float) -> bool:
	if not is_finite(delta) or delta < 0.0 or not is_finite(oxygen):
		return false
	if oxygen > 0.0:
		if running:
			reset_session()
			cancelled.emit()
		return false
	if _expired_sent:
		return false
	if not running:
		running = true
		remaining = grace_seconds
		started.emit(grace_seconds)
		return false
	remaining = maxf(0.0, remaining - delta)
	if not _critical_sent and remaining <= minf(CRITICAL_SECONDS, grace_seconds):
		_critical_sent = true
		critical.emit(remaining)
	if remaining <= 0.0:
		_expired_sent = true
		running = false
		expired.emit()
		return true
	return false
