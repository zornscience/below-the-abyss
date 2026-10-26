class_name SonarRevealTarget
extends Node2D
## Reusable, temporary reveal endpoint. Acoustic receipt schedules, never reveals.

signal echo_received(target: SonarRevealTarget, event: AcousticEvent, distance: float)
signal revealed_for_ping(event_id: StringName)
signal reveal_state_changed(revealed: bool)
@export var target_id: StringName = &""
@export var caption: String = "PLACEHOLDER ECHO"
var registration_generation: int = 0
var _clock: float = 0.0
var _expires_at: float = 0.0
var _seen: Dictionary[StringName, bool] = {}
@onready var receiver: AcousticReceiver = $AcousticReceiver


func _ready() -> void:
	receiver.receiver_id = StringName("sonar-target/" + String(target_id))
	receiver.event_received.connect(_received)
	_refresh()


func bind_bus(bus: AcousticBus) -> Error:
	if not AcousticEvent.valid_token(target_id):
		return ERR_INVALID_PARAMETER
	var previous: AcousticBus = receiver.get_bus()
	var result: Error = receiver.bind_bus(bus)
	if result == OK and previous != bus:
		registration_generation += 1
	return result


func _received(event: AcousticEvent, _strength: float, distance: float) -> void:
	if event.event_type == &"active_sonar":
		echo_received.emit(self, event, distance)


func reveal_for_ping(event_id: StringName, duration: float, arrival_time: float = -1.0) -> Error:
	if not AcousticEvent.valid_token(event_id) or not is_finite(duration) or duration <= 0.0:
		return ERR_INVALID_PARAMETER
	if _seen.has(event_id):
		return ERR_ALREADY_EXISTS
	var arrival: float = _clock if arrival_time == -1.0 else arrival_time
	if not is_finite(arrival) or arrival < 0.0 or not is_finite(arrival + duration):
		return ERR_INVALID_PARAMETER
	_seen[event_id] = true
	var was_revealed: bool = is_revealed()
	_expires_at = maxf(_expires_at, arrival + duration)
	_refresh()
	if was_revealed != is_revealed():
		reveal_state_changed.emit(is_revealed())
	revealed_for_ping.emit(event_id)
	return OK


func advance_reveal(delta: float) -> Error:
	if not is_finite(delta) or delta < 0.0:
		return ERR_INVALID_PARAMETER
	return advance_to(_clock + delta)


func advance_to(simulation_time: float) -> Error:
	if not is_finite(simulation_time) or simulation_time < _clock:
		return ERR_INVALID_PARAMETER
	var was_revealed: bool = is_revealed()
	_clock = simulation_time
	if was_revealed and not is_revealed():
		_refresh()
		reveal_state_changed.emit(false)
	return OK


func is_revealed() -> bool:
	return _expires_at - _clock > 0.000000001


func reset_reveal(simulation_time: float = 0.0) -> void:
	var was_revealed: bool = is_revealed()
	_clock = simulation_time
	_expires_at = 0.0
	_seen.clear()
	registration_generation += 1
	_refresh()
	if was_revealed:
		reveal_state_changed.emit(false)


func _refresh() -> void:
	($Caption as Label).text = "ECHO / " + caption
	($Caption as Label).visible = is_revealed()
	queue_redraw()


func _draw() -> void:
	if not is_revealed():
		return
	var ink: Color = Color("9cf4e4")
	draw_arc(Vector2.ZERO, 23.0, 0.0, TAU, 64, ink, 2.0, true)
	draw_polyline(PackedVector2Array([Vector2(0, -12), Vector2(12, 0),
		Vector2(0, 12), Vector2(-12, 0), Vector2(0, -12)]), ink, 3.0, true)


func _exit_tree() -> void:
	registration_generation += 1
