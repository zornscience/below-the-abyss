class_name MissionBoard
extends VBoxContainer
## Mission presentation only; station owns eligibility and service owns state.

signal back_requested
var _station: WeakRef
var _selected: StringName = &""
var _source: MissionService


func _ready() -> void:
	(%BackMissions as Button).pressed.connect(func() -> void: back_requested.emit())
	(%AcceptMission as Button).pressed.connect(_act.bind(&"accept"))
	(%ClaimMission as Button).pressed.connect(_act.bind(&"claim"))
	(%SyncMissions as Button).pressed.connect(_act.bind(&"sync"))
	(%RecoverMissions as Button).pressed.connect(_act.bind(&"recover"))


func present(station: ServiceStation) -> void:
	if is_instance_valid(_source):
		if _source.missions_changed.is_connected(refresh):
			_source.missions_changed.disconnect(refresh)
		if _source.store.status_changed.is_connected(_status):
			_source.store.status_changed.disconnect(_status)
	_station = weakref(station)
	_source = station.missions
	if not is_instance_valid(_source):
		return
	_source.missions_changed.connect(refresh)
	_source.store.status_changed.connect(_status)
	var list: VBoxContainer = %MissionList
	for child: Node in list.get_children():
		list.remove_child(child)
		child.free()
	for definition: MissionDefinition in _source.definitions():
		var button: Button = Button.new()
		button.text = ("OPTIONAL / " if definition.optional else "MAIN / ") + definition.title
		button.clip_text = true
		button.custom_minimum_size.y = 64
		list.add_child(button)
		button.pressed.connect(_select.bind(definition.stable_id))
		button.focus_entered.connect(_select.bind(definition.stable_id))
	if _source.definitions().size() > 0:
		_selected = _source.definitions()[0].stable_id
	(%MissionFeedback as Label).text = "Accept intentionally. Completion requires evidence; claim only at the station."
	show()
	refresh()
	(%BackMissions as Button).grab_focus()


func _select(id: StringName) -> void:
	_selected = id
	refresh()


func _status() -> void:
	(%MissionSaveStatus as Label).text = _source.store.status if is_instance_valid(_source) else "Missions unavailable."


func refresh() -> void:
	if not is_instance_valid(_source):
		return
	var records: Dictionary = _source.snapshot()
	var definitions: Array[MissionDefinition] = _source.definitions()
	for index: int in range(definitions.size()):
		var definition: MissionDefinition = definitions[index]
		var button: Button = (%MissionList as VBoxContainer).get_child(index) as Button
		button.text = ("OPTIONAL / " if definition.optional else "MAIN / ") + String(records[String(definition.stable_id)].state).to_upper() + "\n" + definition.title
	var record: Dictionary = records.get(String(_selected), {})
	var detail: PackedStringArray = []
	for definition: MissionDefinition in _source.definitions():
		if definition.stable_id != _selected:
			continue
		detail.append(definition.title + " / " + String(record.state).to_upper())
		detail.append(definition.description)
		for objective: MissionObjective in definition.objectives:
			detail.append(("[DONE] " if String(objective.stable_id) in record.objectives else "[ ] ") + objective.description)
		detail.append("ACKNOWLEDGEMENT / " + (definition.acknowledgement if record.state == "claimed" else "Non-economic completion record; claim after completion."))
	(%MissionDetail as Label).text = "\n\n".join(detail)
	(%AcceptMission as Button).disabled = record.get("state") != "available"
	(%ClaimMission as Button).disabled = record.get("state") != "completed"
	var controls: Array[Control] = [%BackMissions]
	for child: Node in (%MissionList as VBoxContainer).get_children():
		controls.append(child as Control)
	for button: Button in [%AcceptMission, %ClaimMission, %SyncMissions, %RecoverMissions]:
		if not button.disabled:
			controls.append(button)
	controls.append(%MissionDetailScroll)
	UiScrollReader.link(controls,%MissionDetailScroll)
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus == null or (focus is Button and (focus as Button).disabled):
		(%BackMissions as Button).grab_focus()
	_status()


func _act(action: StringName) -> void:
	var station: ServiceStation = _station.get_ref() as ServiceStation if _station != null else null
	if station == null:
		return
	var result: Error = station.mission_action(action, _selected)
	(%MissionFeedback as Label).text = ("SAVED / " + String(action).to_upper()) if result == OK else "UNAVAILABLE / " + error_string(result)
	refresh()
