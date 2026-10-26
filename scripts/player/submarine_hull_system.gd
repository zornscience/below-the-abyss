class_name SubmarineHullSystem
extends Node
## Hull state only. Callers supply explicit damage; no collision/depth mechanics.

signal hull_changed(current: float, maximum: float)
signal vessel_destroyed

@export var configuration: SubmarineResourceConfig = SubmarineResourceConfig.new()
var _hull: BoundedResource = BoundedResource.new()
var last_damage_source: StringName = &""

var hull: float:
	get:
		return _hull.value
var max_hull: float:
	get:
		return _hull.maximum


func _init() -> void:
	_connect_pool()


func _ready() -> void:
	if configure(configuration) != OK:
		push_error("Invalid submarine hull configuration; fix the authored profile.")


func _connect_pool() -> void:
	_hull.changed.connect(func(current: float, maximum: float) -> void: hull_changed.emit(current, maximum))
	_hull.depleted.connect(func() -> void: vessel_destroyed.emit())


func configure(profile: SubmarineResourceConfig) -> Error:
	if profile == null or not profile.is_valid():
		return ERR_INVALID_PARAMETER
	configuration = profile
	_hull = BoundedResource.new(profile.max_hull)
	last_damage_source = &""
	_connect_pool()
	hull_changed.emit(hull, max_hull)
	return OK


func apply_damage(amount: float, source_id: StringName = &"unspecified") -> float:
	if not BoundedResource.valid_amount(amount) or amount == 0.0 or hull == 0.0:
		return 0.0
	last_damage_source = source_id
	return _hull.consume(amount)


func restore_hull(amount: float) -> float:
	return _hull.replenish(amount)


func restore_snapshot(value: float) -> Error:
	if not is_finite(value) or value < 0.0 or value > max_hull:
		return ERR_INVALID_PARAMETER
	var pool: BoundedResource = BoundedResource.new(max_hull)
	pool.set_value(value)
	_hull = pool
	_connect_pool()
	last_damage_source = &""
	hull_changed.emit(hull, max_hull)
	return OK
