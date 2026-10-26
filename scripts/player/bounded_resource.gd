class_name BoundedResource
extends RefCounted
## Runtime scalar with finite inputs, saturating transfers and edge notifications.

signal changed(current: float, maximum: float)
signal depleted

const EPSILON: float = 0.00000001
var _maximum: float
var _value: float
var maximum: float:
	get:
		return _maximum
var value: float:
	get:
		return _value


func _init(capacity: float = 100.0) -> void:
	assert(is_finite(capacity) and capacity > 0.0)
	_maximum = capacity
	_value = capacity


static func valid_amount(amount: float) -> bool:
	return is_finite(amount) and amount >= 0.0


func set_value(requested: float) -> Error:
	if not is_finite(requested):
		return ERR_INVALID_PARAMETER
	var next: float = _bounded_value(requested)
	if next == _value:
		return OK
	var became_empty: bool = _value > 0.0 and next == 0.0
	_value = next
	changed.emit(next, _maximum)
	if became_empty:
		depleted.emit()
	return OK


func _bounded_value(requested: float) -> float:
	var next: float = clampf(requested, 0.0, _maximum)
	# Eliminate accumulated sub-nanounit drift at the endpoints, without using
	# approximate equality to suppress legitimate small change notifications.
	var tolerance: float = minf(EPSILON, _maximum * 0.000000001)
	if next < tolerance:
		next = 0.0
	elif _maximum - next < tolerance:
		next = _maximum
	return next


func consume(amount: float) -> float:
	if not valid_amount(amount):
		return 0.0
	var next: float = _bounded_value(_value - minf(amount, _value))
	var removed: float = _value - next
	set_value(next)
	return removed


func try_consume(amount: float) -> bool:
	# Discrete costs are all-or-nothing; passive drains use saturating consume.
	if not valid_amount(amount) or amount > _value:
		return false
	consume(amount)
	return true


func replenish(amount: float) -> float:
	if not valid_amount(amount):
		return 0.0
	# Avoid overflow when finite caller input is close to the float limit.
	var next: float = _bounded_value(_value + minf(amount, _maximum - _value))
	var added: float = next - _value
	set_value(next)
	return added
