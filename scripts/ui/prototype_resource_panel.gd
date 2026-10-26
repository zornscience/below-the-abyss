class_name PrototypeResourcePanel
extends PanelContainer
## Temporary signal-driven indicators and test requests, not a production HUD.

signal test_requested(kind: StringName)
signal test_controls_focused

var _battery_depletions: int = 0
var _oxygen_depletions: int = 0
var _hull_depletions: int = 0


func _ready() -> void:
	focus_entered.connect(focus_test_controls)
	var controls: Array[Button] = [%TestHull, %TestBattery, %TestOxygen, %RefillAll, %Pilot]
	var kinds: Array[StringName] = [&"hull", &"battery", &"oxygen", &"refill", &"pilot"]
	for index: int in range(controls.size()):
		controls[index].pressed.connect(_request.bind(kinds[index]))
		controls[index].focus_entered.connect(func() -> void: test_controls_focused.emit())
		var previous: Button = controls[posmod(index - 1, controls.size())]
		var next: Button = controls[(index + 1) % controls.size()]
		for property: String in ["focus_previous", "focus_neighbor_left", "focus_neighbor_top"]:
			controls[index].set(property, controls[index].get_path_to(previous))
		for property: String in ["focus_next", "focus_neighbor_right", "focus_neighbor_bottom"]:
			controls[index].set(property, controls[index].get_path_to(next))
	_set_expanded(false)


func _set_expanded(expanded: bool) -> void:
	(%Buttons as HFlowContainer).visible = expanded
	(%Depletions as Label).visible = expanded


func bind_sources(resources: SubmarineResourceSystem, hull: SubmarineHullSystem) -> void:
	resources.battery_changed.connect(_battery_changed)
	resources.oxygen_changed.connect(_oxygen_changed)
	hull.hull_changed.connect(_hull_changed)
	resources.battery_depleted.connect(_battery_depleted)
	resources.oxygen_depleted.connect(_oxygen_depleted)
	hull.vessel_destroyed.connect(_hull_depleted)
	_battery_changed(resources.battery, resources.max_battery)
	_oxygen_changed(resources.oxygen, resources.max_oxygen)
	_hull_changed(hull.hull, hull.max_hull)
	_update_counts()


func focus_test_controls() -> void:
	show()
	_set_expanded(true)
	(%TestHull as Button).grab_focus()


func has_test_focus() -> bool:
	var owner: Control = get_viewport().gui_get_focus_owner()
	return owner != null and (owner == self or is_ancestor_of(owner))


func release_test_focus() -> void:
	var owner: Control = get_viewport().gui_get_focus_owner()
	if owner != null and (owner == self or is_ancestor_of(owner)):
		owner.release_focus()
	_set_expanded(false)
	hide()


func _request(kind: StringName) -> void:
	test_requested.emit(kind)


func _battery_changed(current: float, maximum: float) -> void:
	(%Battery as Label).text = "Battery: %.1f / %.1f%s" % [current, maximum, " — EMPTY" if current == 0.0 else ""]


func _oxygen_changed(current: float, maximum: float) -> void:
	(%Oxygen as Label).text = "Oxygen: %.1f / %.1f%s" % [current, maximum, " — EMPTY" if current == 0.0 else ""]


func _hull_changed(current: float, maximum: float) -> void:
	(%Hull as Label).text = "Hull: %.1f / %.1f%s" % [current, maximum, " — DEPLETED" if current == 0.0 else ""]


func _battery_depleted() -> void:
	_battery_depletions += 1
	_update_counts()


func _oxygen_depleted() -> void:
	_oxygen_depletions += 1
	_update_counts()


func _hull_depleted() -> void:
	_hull_depletions += 1
	_update_counts()


func _update_counts() -> void:
	(%Depletions as Label).text = "Depletion events — hull: %d   battery: %d   oxygen: %d. No loss consequences yet." % [
		_hull_depletions, _battery_depletions, _oxygen_depletions,
	]
