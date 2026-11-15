class_name GameplayAudio
extends Node
## Read-only adapter. No AcousticBus registration/dispatch and no simulation writes.

var mixer: SoundscapeMixer
var _scene: ShelfPrototype
var _links: Array[Dictionary] = []
var _passive_ids: Dictionary[StringName, StringName] = {}
var _scan_id: StringName
var _scan_complete_id: StringName
var _hull: float = 100.0
var _announced: Dictionary[StringName, bool] = {}
var _alarm_remaining: float = 0.0
var _phase: int = PredatorState.Phase.QUIET
var _near_predator: bool = false


func setup(scene: ShelfPrototype, audio: SoundscapeMixer) -> void:
	_scene = scene
	mixer = audio
	_hull = scene.submarine.hull_system.hull
	_link(scene.submarine.sonar.pulse_emitted, _ping)
	_link(scene.submarine.sonar.echo_revealed, _echo)
	_link(scene.submarine.passive.contacts_changed, _passive_changed)
	_link(scene.submarine.scanner.state_changed, _scan_changed)
	_link(scene.research.scan_completed, _completed)
	_link(scene.submarine.hull_system.hull_changed, _hull_changed)
	_link(scene.submarine.damage_system.pressure_damage_applied, _pressure_damage)
	_link(scene.submarine.damage_system.collision_damage_applied, _impact)
	_link(scene.station.service_applied, _serviced)
	_link(scene.station_menu.visibility_changed, _station_changed)
	_link(scene.creature.brain.state_changed, _creature_changed)
	_link(scene.predator.threat_changed, _threat_changed)
	_link(scene.missions.mission_completed, _mission_completed)
	_link(scene.get_viewport().gui_focus_changed, _focus_changed)
	_link(scene.submarine.simulation_enabled_changed, _simulation_changed)


func _link(source: Signal, callback: Callable) -> void:
	if not source.is_connected(callback):
		source.connect(callback)
		_links.append({"signal": source, "callback": callback})


func _ping(_event: AcousticEvent) -> void:
	mixer.request(&"ping")


func _echo(_event_id: StringName, _target_id: StringName) -> void:
	# This signal occurs only at the authoritative wavefront reveal, not receipt.
	mixer.request(&"echo")


static func contact_cue(classification: StringName) -> StringName:
	match classification:
		&"mechanical": return &"mechanical"
		&"geological": return &"geological"
		&"biological", &"marine_life": return &"biological"
		_: return &"unknown"


func _passive_changed() -> void:
	var live: Dictionary[StringName, StringName] = {}
	for contact: Dictionary in _scene.submarine.passive.contacts_snapshot():
		live[contact.source_id] = contact.event_id
		if _passive_ids.get(contact.source_id, &"") != contact.event_id:
			mixer.request(contact_cue(contact.classification))
	_passive_ids = live


func _scan_changed() -> void:
	var active: StringName = _scene.submarine.scanner.snapshot().active_id
	if active != &"" and active != _scan_id:
		mixer.request(&"scan_start")
	_scan_id = active


func _completed(id: StringName) -> void:
	if id != _scan_complete_id:
		_scan_complete_id = id
		mixer.request(&"complete")
		# Completion is also the research acknowledgement; one quiet cue, no stack.


func _hull_changed(current: float, _maximum: float) -> void:
	if current < _hull and _scene.submarine.hull_system.last_damage_source != &"":
		mixer.request(&"damage")
	_hull = current


func _pressure_damage(_amount: float) -> void:
	mixer.request(&"creak")


func _impact(_amount: float, _speed: float) -> void:
	mixer.request(&"impact")


func _serviced(_result: Dictionary) -> void:
	mixer.request(&"service")


func _station_changed() -> void:
	if _scene.station_menu.visible:
		mixer.request(&"dock")


func _creature_changed(state: int) -> void:
	if state == CreatureState.State.INVESTIGATE and _scene.creature.global_position.distance_to(_scene.submarine.global_position) <= 600.0:
		mixer.request(&"biological")


func _threat_changed() -> void:
	var phase: int = _scene.predator.threat.phase
	var near: bool = _scene.predator.hud_snapshot().visible
	if phase != _phase and near:
		match phase:
			PredatorState.Phase.ALERT: mixer.request(&"predator_alert")
			PredatorState.Phase.PURSUE: mixer.request(&"predator_pursue")
			PredatorState.Phase.DISENGAGE: mixer.request(&"retreat")
	if near and not _near_predator and phase == PredatorState.Phase.QUIET:
		mixer.request(&"unknown")
	_phase = phase
	_near_predator = near


func _mission_completed(_id: StringName) -> void:
	mixer.request(&"acknowledge")


func _focus_changed(control: Control) -> void:
	if control != null and control.is_visible_in_tree():
		mixer.request(&"ui")


func _simulation_changed(enabled: bool) -> void:
	if not enabled:
		# Prevent a held sound cue leaking into menus; continuous layers fade down.
		mixer.stop_cues()


## Life-support countdown: the existing oxygen alarm cue, requested at depletion and
## at the critical threshold. No new audio. The mixer's mute and overlap rules apply.
func life_support_alarm() -> bool:
	if not is_instance_valid(mixer):
		return false
	return mixer.request(&"oxygen")


func reset_session() -> void:
	mixer.reset_session()
	_passive_ids.clear()
	_scan_id = &""
	_scan_complete_id = &""
	_announced.clear()
	_alarm_remaining = 0.0
	_phase = PredatorState.Phase.QUIET
	_near_predator = false
	_hull = _scene.submarine.hull_system.hull


func _process(delta: float) -> void:
	if not is_instance_valid(_scene) or not is_instance_valid(mixer):
		return
	var body: SubmarineController = _scene.submarine
	var running: bool = body.is_physics_processing()
	var near: bool = _scene.predator.hud_snapshot().visible
	var threat: float = 0.0
	if near and _phase in [PredatorState.Phase.ALERT, PredatorState.Phase.PURSUE]:
		threat = 0.45 if _phase == PredatorState.Phase.ALERT else 1.0
	var thrust: float = Input.get_vector("move_left", "move_right", "move_up", "move_down").length()
	mixer.set_context(running, body.damage_system.depth_m, thrust,
		body.damage_system.warning_state == SubmarineDamageSystem.WarningState.EXCEEDED, threat, _scan_id != &"")
	if not running:
		return
	_alarm_remaining = maxf(0.0, _alarm_remaining - delta)
	var fractions: Dictionary = {&"hull": body.hull_system.hull / body.hull_system.max_hull,
		&"oxygen": body.resource_system.oxygen / body.resource_system.max_oxygen,
		&"battery": body.resource_system.battery / body.resource_system.max_battery}
	for id: StringName in [&"hull", &"oxygen", &"battery"]:
		if fractions[id] > mixer.configuration.low_resource_fraction + 0.05:
			_announced.erase(id)
		elif fractions[id] <= mixer.configuration.low_resource_fraction and not _announced.has(id) and _alarm_remaining <= 0.0:
			# Consume silent episodes too; unmuting must not replay queued alarms.
			mixer.request(id)
			_announced[id] = true
			_alarm_remaining = 2.0


func _exit_tree() -> void:
	for link: Dictionary in _links:
		var source: Signal = link.signal
		if not source.is_null() and is_instance_valid(source.get_object()) and source.is_connected(link.callback):
			source.disconnect(link.callback)
	_links.clear()
