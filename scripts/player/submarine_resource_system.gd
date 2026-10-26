class_name SubmarineResourceSystem
extends Node
## Battery/oxygen interfaces and fixed-physics-step drain; owns no movement rules.

signal battery_changed(current: float, maximum: float)
signal oxygen_changed(current: float, maximum: float)
signal battery_depleted
signal oxygen_depleted

@export var configuration: SubmarineResourceConfig = SubmarineResourceConfig.new()
var _battery: BoundedResource = BoundedResource.new()
var _oxygen: BoundedResource = BoundedResource.new()
var _idle_rate: float = 0.25
var _thrust_rate: float = 1.5
var _oxygen_rate: float = 0.5

var battery: float:
	get:
		return _battery.value
var max_battery: float:
	get:
		return _battery.maximum
var oxygen: float:
	get:
		return _oxygen.value
var max_oxygen: float:
	get:
		return _oxygen.maximum


func _init() -> void:
	_connect_pools()


func _ready() -> void:
	if configure(configuration) != OK:
		push_error("Invalid submarine resource configuration; fix the authored profile.")


func _connect_pools() -> void:
	_battery.changed.connect(func(current: float, maximum: float) -> void: battery_changed.emit(current, maximum))
	_oxygen.changed.connect(func(current: float, maximum: float) -> void: oxygen_changed.emit(current, maximum))
	_battery.depleted.connect(func() -> void: battery_depleted.emit())
	_oxygen.depleted.connect(func() -> void: oxygen_depleted.emit())


func configure(profile: SubmarineResourceConfig) -> Error:
	if profile == null or not profile.is_valid():
		return ERR_INVALID_PARAMETER
	# Cache validated values. Shared authored Resources never hold vessel state.
	configuration = profile
	_battery = BoundedResource.new(profile.max_battery)
	_oxygen = BoundedResource.new(profile.max_oxygen)
	_idle_rate = profile.battery_idle_drain_per_second
	_thrust_rate = profile.battery_thrust_drain_per_second
	_oxygen_rate = profile.oxygen_drain_per_second
	_connect_pools()
	battery_changed.emit(battery, max_battery)
	oxygen_changed.emit(oxygen, max_oxygen)
	return OK


func try_consume_battery(amount: float) -> bool:
	return _battery.try_consume(amount)


func consume_battery(amount: float) -> float:
	return _battery.consume(amount)


func restore_battery(amount: float) -> float:
	return _battery.replenish(amount)


func try_consume_oxygen(amount: float) -> bool:
	return _oxygen.try_consume(amount)


func consume_oxygen(amount: float) -> float:
	return _oxygen.consume(amount)


func restore_oxygen(amount: float) -> float:
	return _oxygen.replenish(amount)


func advance(delta: float, thrust_strength: float = 0.0) -> Error:
	if not is_finite(delta) or delta < 0.0 or not is_finite(thrust_strength) or thrust_strength < 0.0:
		return ERR_INVALID_PARAMETER
	if delta == 0.0:
		return OK
	# Saturate each term before adding, so extreme finite elapsed durations/rates
	# cannot overflow the actual transfer or turn a drain into a non-finite value.
	var idle_cost: float = minf(battery, _idle_rate * delta)
	var thrust_cost: float = minf(battery - idle_cost, (_thrust_rate * minf(thrust_strength, 1.0)) * delta)
	_battery.consume(idle_cost + thrust_cost)
	_oxygen.consume(minf(oxygen, _oxygen_rate * delta))
	return OK


func restore_snapshot(saved_battery: float, saved_oxygen: float) -> Error:
	if not is_finite(saved_battery) or saved_battery < 0.0 or saved_battery > max_battery or not is_finite(saved_oxygen) or saved_oxygen < 0.0 or saved_oxygen > max_oxygen:
		return ERR_INVALID_PARAMETER
	var battery_pool: BoundedResource = BoundedResource.new(max_battery)
	var oxygen_pool: BoundedResource = BoundedResource.new(max_oxygen)
	battery_pool.set_value(saved_battery)
	oxygen_pool.set_value(saved_oxygen)
	_battery = battery_pool
	_oxygen = oxygen_pool
	_connect_pools()
	battery_changed.emit(battery, max_battery)
	oxygen_changed.emit(oxygen, max_oxygen)
	return OK
