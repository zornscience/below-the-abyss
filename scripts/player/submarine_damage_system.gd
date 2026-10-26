class_name SubmarineDamageSystem
extends Node
## Deterministic simulation-time rules. Hull mutation stays in SubmarineHullSystem.

enum WarningState { SAFE, APPROACHING, EXCEEDED }

signal depth_changed(depth_m: float, maximum_depth_m: float)
signal warning_changed(state: WarningState)
signal maximum_depth_changed(maximum_depth_m: float)
signal pressure_damage_applied(amount: float)
signal collision_damage_applied(amount: float, approach_speed: float)

const CLOCK_EPSILON: float = 0.000000001
@export var configuration: SubmarineDamageConfig = SubmarineDamageConfig.new()
var _rules: SubmarineDamageConfig = SubmarineDamageConfig.new()
var _depth_m: float = 0.0
var _maximum_depth_m: float = 300.0
var _grace_remaining: float = 2.0
var _cooldown_remaining: float = 0.0
var _contact_latched: bool = false
var _warning: WarningState = WarningState.SAFE

var depth_m: float:
	get:
		return _depth_m
var warning_state: WarningState:
	get:
		return _warning
var grace_remaining_seconds: float:
	get:
		return _grace_remaining
var pressure_damage_per_second: float:
	get:
		return _rules.pressure_damage_per_second


func _ready() -> void:
	if configure(configuration) != OK:
		push_error("Invalid submarine depth/damage profile.")


func configure(profile: SubmarineDamageConfig) -> Error:
	if profile == null or not profile.is_valid():
		return ERR_INVALID_PARAMETER
	configuration = profile
	_rules = profile.duplicate() as SubmarineDamageConfig
	_maximum_depth_m = _rules.safe_operating_depth_m
	_depth_m = 0.0
	_grace_remaining = _rules.pressure_grace_seconds
	_cooldown_remaining = 0.0
	_contact_latched = false
	_set_warning(WarningState.SAFE)
	maximum_depth_changed.emit(_maximum_depth_m)
	depth_changed.emit(_depth_m, _maximum_depth_m)
	return OK


func get_maximum_depth_m() -> float:
	return _maximum_depth_m


func set_maximum_depth_m(value: float) -> Error:
	# Future equipment can set this effective operating rating. No upgrade
	# inventory, unlocks or persistence are implemented by this interface.
	if not is_finite(value) or value <= _rules.warning_margin_m:
		return ERR_INVALID_PARAMETER
	if value == _maximum_depth_m:
		return OK
	_maximum_depth_m = value
	_grace_remaining = _rules.pressure_grace_seconds
	_update_warning()
	maximum_depth_changed.emit(value)
	depth_changed.emit(_depth_m, value)
	return OK


func _set_warning(state: WarningState) -> void:
	if state != _warning:
		_warning = state
		warning_changed.emit(state)


func _update_warning() -> void:
	if _depth_m > _maximum_depth_m:
		_set_warning(WarningState.EXCEEDED)
	elif _depth_m >= _maximum_depth_m - _rules.warning_margin_m:
		_set_warning(WarningState.APPROACHING)
	else:
		_set_warning(WarningState.SAFE)


func advance(delta: float, sampled_depth_m: float, hull: SubmarineHullSystem) -> Error:
	if hull == null or not is_finite(delta) or delta < 0.0 \
		or not is_finite(sampled_depth_m) or sampled_depth_m < 0.0:
		return ERR_INVALID_PARAMETER
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	if _cooldown_remaining < CLOCK_EPSILON:
		_cooldown_remaining = 0.0
	if sampled_depth_m != _depth_m:
		_depth_m = sampled_depth_m
		depth_changed.emit(_depth_m, _maximum_depth_m)
	_update_warning()
	if _warning != WarningState.EXCEEDED:
		_grace_remaining = _rules.pressure_grace_seconds
		return OK
	var grace_used: float = minf(delta, _grace_remaining)
	_grace_remaining = maxf(0.0, _grace_remaining - grace_used)
	if _grace_remaining < CLOCK_EPSILON:
		_grace_remaining = 0.0
	var damaging_seconds: float = maxf(0.0, delta - grace_used)
	if damaging_seconds > CLOCK_EPSILON:
		var amount: float = minf(hull.hull, _rules.pressure_damage_per_second * damaging_seconds)
		var removed: float = hull.apply_damage(amount, &"pressure")
		if removed > 0.0:
			pressure_damage_applied.emit(removed)
	return OK


func observe_contacts(approach_speed: float, has_contact: bool, hull: SubmarineHullSystem) -> Error:
	if hull == null or not is_finite(approach_speed) or approach_speed < 0.0:
		return ERR_INVALID_PARAMETER
	if not has_contact:
		_contact_latched = false
		return OK
	if approach_speed <= _rules.impact_speed_threshold or _contact_latched:
		return OK
	# Consume the qualifying contact episode even during cooldown; never queue a
	# suppressed impact to fire later while still pushing against the same wall.
	_contact_latched = true
	if _cooldown_remaining > 0.0:
		return OK
	var amount: float = minf(
		_rules.maximum_collision_damage,
		(approach_speed - _rules.impact_speed_threshold) * _rules.collision_damage_per_speed)
	var removed: float = hull.apply_damage(amount, &"collision")
	if removed > 0.0:
		_cooldown_remaining = _rules.collision_cooldown_seconds
		collision_damage_applied.emit(removed, approach_speed)
	return OK
