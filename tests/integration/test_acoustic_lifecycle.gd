extends GutTest

const EXAMPLE: PackedScene = preload("res://scenes/main/acoustic_contract_example.tscn")
var _bus: AcousticBus
var _emitter: AcousticEmitter
var _received: Array[StringName] = []


func before_each() -> void:
	_received.clear()
	_bus = AcousticBus.new()
	add_child_autofree(_bus)
	_emitter = AcousticEmitter.new()
	_emitter.source_id = &"source"
	add_child_autofree(_emitter)
	assert_eq(_emitter.bind_bus(_bus), OK)


func _receiver(id: StringName) -> AcousticReceiver:
	var receiver: AcousticReceiver = AcousticReceiver.new()
	receiver.receiver_id = id
	add_child_autofree(receiver)
	receiver.event_received.connect(func(_event: AcousticEvent, _strength: float, _distance: float) -> void: _received.append(id))
	assert_eq(receiver.bind_bus(_bus), OK)
	return receiver


func test_example_delivers_to_eligible_receivers_once_and_excludes_far_and_filtered() -> void:
	var example: AcousticContractExample = EXAMPLE.instantiate() as AcousticContractExample
	example.quit_when_finished = false
	add_child_autofree(example)
	assert_eq(example.result, OK)
	assert_eq(example.deliveries, [&"boundary", &"near"])
	assert_eq((example.get_node("AcousticBus") as AcousticBus).history_count(), 1)


func test_freed_queued_and_exited_receivers_are_cleaned_without_stale_delivery() -> void:
	var freed: AcousticReceiver = _receiver(&"freed")
	freed.free()
	assert_eq(_bus.receiver_count(), 0)
	var queued: AcousticReceiver = _receiver(&"queued")
	queued.queue_free()
	assert_eq(_bus.receiver_count(), 0, "Queued endpoints are ineligible immediately.")
	var exited: AcousticReceiver = _receiver(&"exited")
	remove_child(exited)
	assert_eq(_bus.receiver_count(), 0)
	assert_null(exited.get_bus())
	assert_eq(_emitter.emit_event(&"first", 1.0), OK)
	assert_true(_received.is_empty())
	add_child(exited)
	assert_eq(exited.bind_bus(_bus), OK)
	assert_eq(_emitter.emit_event(&"second", 2.0), OK)
	assert_eq(_received, [&"exited"])
	await get_tree().process_frame


func test_emitter_exit_clears_registration_and_requires_explicit_rebind() -> void:
	_receiver(&"listener")
	remove_child(_emitter)
	assert_eq(_bus.emitter_count(), 0)
	assert_null(_emitter.get_bus())
	assert_eq(_emitter.emit_event(&"first", 1.0), ERR_UNCONFIGURED)
	add_child(_emitter)
	assert_eq(_emitter.bind_bus(_bus), OK)
	assert_eq(_emitter.emit_event(&"first", 1.0), OK)
	assert_eq(_received, [&"listener"])


func test_bus_exit_detaches_live_endpoints_and_keeps_session_history_until_destroyed() -> void:
	var receiver: AcousticReceiver = _receiver(&"listener")
	assert_eq(_emitter.emit_event(&"first", 1.0), OK)
	remove_child(_bus)
	assert_null(receiver.get_bus())
	assert_null(_emitter.get_bus())
	assert_eq(_bus.receiver_count(), 0)
	assert_eq(_bus.emitter_count(), 0)
	add_child(_bus)
	assert_eq(_emitter.bind_bus(_bus), OK)
	assert_eq(receiver.bind_bus(_bus), OK)
	assert_eq(_emitter.emit_event(&"first", 1.0), ERR_ALREADY_EXISTS)
	assert_eq(_received, [&"listener"])


func test_removal_and_reregistration_during_callback_cannot_deliver_a_stale_snapshot() -> void:
	var first: AcousticReceiver = _receiver(&"a")
	var later: AcousticReceiver = _receiver(&"b")
	var newcomer: AcousticReceiver = AcousticReceiver.new()
	newcomer.receiver_id = &"new"
	add_child_autofree(newcomer)
	newcomer.event_received.connect(func(_event: AcousticEvent, _strength: float, _distance: float) -> void: _received.append(&"new"))
	first.event_received.connect(func(_event: AcousticEvent, _strength: float, _distance: float) -> void:
		later.bind_bus(null)
		later.bind_bus(_bus)
		newcomer.bind_bus(_bus))
	assert_eq(_emitter.emit_event(&"first", 1.0), OK)
	assert_eq(_received, [&"a"], "Rebound and newly registered endpoints wait for the next event.")
	first.bind_bus(null)
	assert_eq(_emitter.emit_event(&"second", 2.0), OK)
	assert_eq(_received, [&"a", &"b", &"new"])


func test_queue_free_and_immediate_free_during_callbacks_cancel_later_deliveries() -> void:
	var first: AcousticReceiver = _receiver(&"a")
	var queued: AcousticReceiver = _receiver(&"b")
	var freed: AcousticReceiver = _receiver(&"c")
	first.event_received.connect(func(_event: AcousticEvent, _strength: float, _distance: float) -> void:
		queued.queue_free()
		freed.free())
	assert_eq(_emitter.emit_event(&"first", 1.0), OK)
	assert_eq(_received, [&"a"])
	assert_eq(_bus.receiver_count(), 1)
	await get_tree().process_frame


func test_queued_bus_stops_remaining_deliveries_and_detaches_everyone() -> void:
	var first: AcousticReceiver = _receiver(&"a")
	var later: AcousticReceiver = _receiver(&"b")
	first.event_received.connect(func(_event: AcousticEvent, _strength: float, _distance: float) -> void: _bus.queue_free())
	assert_eq(_emitter.emit_event(&"first", 1.0), OK)
	assert_eq(_received, [&"a"])
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(later.get_bus())
	assert_null(_emitter.get_bus())


func test_event_metadata_uses_emitter_world_position_and_caller_simulation_time() -> void:
	var parent: Node2D = Node2D.new()
	parent.position = Vector2(100, 200)
	parent.rotation = 0.5
	add_child_autofree(parent)
	_emitter.reparent(parent)
	_emitter.position = Vector2(30, 40)
	var receiver: AcousticReceiver = _receiver(&"listener")
	receiver.global_position = _emitter.global_position
	var events: Array[AcousticEvent] = []
	receiver.event_received.connect(func(event: AcousticEvent, _strength: float, _distance: float) -> void: events.append(event))
	# Reparent exits the tree and deliberately unbinds the emitter.
	assert_eq(_emitter.bind_bus(_bus), OK)
	assert_eq(_emitter.emit_event(&"session/source/0001", 123.25), OK)
	assert_eq(events.size(), 1)
	assert_eq(events[0].origin, _emitter.global_position)
	assert_eq(events[0].simulation_time, 123.25)
	assert_eq(events[0].source_id, &"source")
	assert_eq(events[0].event_id, &"session/source/0001")
