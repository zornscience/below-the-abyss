class_name StationMenu
extends Control
## Explicit actions and read-only expedition notices; owns no resource rules.

signal close_requested
var _station: WeakRef
@onready var _services: Control = %ServicesPage
@onready var _upgrades_page: Control = %UpgradesPage
@onready var _board: Control = %BoardPage


func _ready() -> void:
	(%Undock as Button).pressed.connect(func() -> void: close_requested.emit())
	(%OpenBoard as Button).pressed.connect(show_board)
	(%BackServices as Button).pressed.connect(show_services)
	(%OpenUpgrades as Button).pressed.connect(show_upgrades)
	(%BackUpgrades as Button).pressed.connect(show_services)
	(%RecoverUpgrades as Button).pressed.connect(_recover_upgrades)
	(%InstallSonar as Button).pressed.connect(_install_upgrade.bind(0))
	(%InstallDepth as Button).pressed.connect(_install_upgrade.bind(1))
	var names: Array[String] = ["RepairHull", "ChargeBattery", "RefillOxygen", "ServiceAll"]
	for index: int in range(names.size()):
		(get_node("%" + names[index]) as Button).pressed.connect(_perform.bind(ServiceStation.SERVICES[index]))


func _live_station() -> ServiceStation:
	return _station.get_ref() as ServiceStation if _station != null else null


func present(station: ServiceStation) -> void:
	var previous: ServiceStation = _live_station()
	if previous != null and previous.availability_changed.is_connected(_availability_changed):
		previous.availability_changed.disconnect(_availability_changed)
	_station = weakref(station)
	station.availability_changed.connect(_availability_changed)
	(%StationTitle as Label).text = station.station_name() + " / DOCKED"
	(%ServiceFeedback as Label).text = "Choose a service. No supplies are restored by arrival or opening this menu."
	var list: VBoxContainer = %NoticeList
	for child: Node in list.get_children():
		list.remove_child(child)
		child.free()
	var notices: Array[StationNotice] = station.notices_snapshot()
	var controls: Array[Control] = [%BackServices]
	for notice: StationNotice in notices:
		var button: Button = Button.new()
		button.text = notice.title
		button.clip_text = true
		button.custom_minimum_size.y = 44
		button.pressed.connect(_read_notice.bind(notice.title, notice.description))
		button.focus_entered.connect(_read_notice.bind(notice.title, notice.description))
		list.add_child(button)
		controls.append(button)
	_wire_focus(controls)
	(%NoticeText as Label).text = "No notices posted." if notices.is_empty() else "Select an expedition notice to read. Information only; no mission is accepted."
	show()
	show_services()


func _wire_focus(controls: Array[Control]) -> void:
	for index: int in range(controls.size()):
		for property: String in ["focus_previous", "focus_neighbor_top", "focus_neighbor_left"]:
			controls[index].set(property, controls[index].get_path_to(controls[posmod(index - 1, controls.size())]))
		for property: String in ["focus_next", "focus_neighbor_bottom", "focus_neighbor_right"]:
			controls[index].set(property, controls[index].get_path_to(controls[(index + 1) % controls.size()]))


func _refresh() -> void:
	var station: ServiceStation = _live_station()
	var names: Array[String] = ["RepairHull", "ChargeBattery", "RefillOxygen", "ServiceAll"]
	var titles: Array[String] = ["Repair hull", "Charge battery", "Refill oxygen", "Service all"]
	var previews: PackedStringArray = []
	var controls: Array[Control] = [%Undock]
	for index: int in range(names.size()):
		var button: Button = get_node("%" + names[index]) as Button
		var quote: Dictionary = station.quote(ServiceStation.SERVICES[index]) if station != null else {"error": ERR_UNCONFIGURED, "reason": "Station unavailable"}
		button.disabled = quote.error != OK
		button.text = titles[index] + (" / FREE" if not button.disabled else " / unavailable")
		if not button.disabled:
			controls.append(button)
		if index < 3:
			var kind: StringName = ServiceStation.SERVICES[index]
			if quote.has("before"):
				previews.append("%s: %.1f / %.1f → %.1f · %s" % [titles[index], quote.before[kind], quote.before["max_" + String(kind)], quote.after[kind], quote.reason])
			else:
				previews.append(titles[index] + ": " + String(quote.reason))
	controls.append(%OpenBoard as Control)
	controls.append(%OpenUpgrades as Control)
	_wire_focus(controls)
	(%ServicePreview as Label).text = "\n".join(previews)
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus == null or (focus is Button and (focus as Button).disabled):
		(%Undock as Button).grab_focus()


func _perform(kind: StringName) -> void:
	var station: ServiceStation = _live_station()
	if station == null:
		(%ServiceFeedback as Label).text = "Station unavailable. Return to piloting."
		return
	var result: Dictionary = station.perform(kind)
	if result.error != OK:
		(%ServiceFeedback as Label).text = "UNAVAILABLE / " + String(result.reason)
	else:
		(%ServiceFeedback as Label).text = "FREE SERVICE COMPLETE\nHull %.1f → %.1f · Battery %.1f → %.1f · Oxygen %.1f → %.1f" % [result.before.hull, result.after.hull, result.before.battery, result.after.battery, result.before.oxygen, result.after.oxygen]
	_refresh()


func show_services() -> void:
	_upgrades_page.hide()
	_board.hide()
	_services.show()
	_refresh()
	(%Undock as Button).grab_focus()


func show_board() -> void:
	_upgrades_page.hide()
	_services.hide()
	_board.show()
	(%BackServices as Button).grab_focus()


func _read_notice(title: String, description: String) -> void:
	(%NoticeText as Label).text = title + "\n\n" + description


func _input(event: InputEvent) -> void:
	if visible and not event.is_echo() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		if _board.visible or _upgrades_page.visible:
			show_services()
		else:
			close_requested.emit()


func _process(_delta: float) -> void:
	if visible and _services.visible:
		_refresh()


func _availability_changed() -> void:
	if visible and _services.visible:
		_refresh()


func show_upgrades() -> void:
	_services.hide()
	_board.hide()
	_upgrades_page.show()
	(%UpgradeFeedback as Label).text = "Intentional installation only. No prerequisites, materials or currency."
	_refresh_upgrades()
	(%BackUpgrades as Button).grab_focus()


func _upgrade_source() -> SubmarineUpgrades:
	var station: ServiceStation = _live_station()
	return station.upgrades if station != null else null


func _refresh_upgrades() -> void:
	var source: SubmarineUpgrades = _upgrade_source()
	var previews: PackedStringArray = []
	var controls: Array[Control] = [%BackUpgrades]
	var definitions: Array[UpgradeDefinition] = source.definitions() if source != null else [] as Array[UpgradeDefinition]
	for index: int in range(2):
		var button: Button = %InstallSonar if index == 0 else %InstallDepth
		var kind: UpgradeDefinition.Capability = UpgradeDefinition.Capability.SONAR_RADIUS if index == 0 else UpgradeDefinition.Capability.SAFE_DEPTH
		var found: bool = false
		for definition: UpgradeDefinition in definitions:
			if definition.capability != kind:
				continue
			found = true
			var installed: bool = source.is_installed(definition.stable_id)
			var unit: String = "world units" if index == 0 else "meters"
			previews.append("%s\n%.0f → %.0f %s · %s" % [definition.display_name, definition.baseline_value,
				definition.upgraded_value, unit, "INSTALLED / PERSISTENT" if installed else "AVAILABLE / FREE"])
			button.text = ("Sonar range" if index == 0 else "Pressure hull") + (" / installed" if installed else " / install FREE")
			button.disabled = installed
		if not found:
			button.disabled = true
		if not button.disabled:
			controls.append(button)
	controls.append(%RecoverUpgrades)
	_wire_focus(controls)
	(%UpgradePreview as Label).text = "\n\n".join(previews)
	(%UpgradeSaveStatus as Label).text = source.store.status if source != null else "Upgrade system unavailable. Return to services."
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus == null or (focus is Button and (focus as Button).disabled):
		(%BackUpgrades as Button).grab_focus()


func _install_upgrade(index: int) -> void:
	var source: SubmarineUpgrades = _upgrade_source()
	var station: ServiceStation = _live_station()
	if source == null or station == null:
		return
	var kind: UpgradeDefinition.Capability = UpgradeDefinition.Capability.SONAR_RADIUS if index == 0 else UpgradeDefinition.Capability.SAFE_DEPTH
	for definition: UpgradeDefinition in source.definitions():
		if definition.capability == kind:
			var result: Error = station.install_upgrade(definition.stable_id)
			(%UpgradeFeedback as Label).text = ("INSTALLED / %.0f → %.0f · FREE · Saved locally" % [definition.baseline_value, definition.upgraded_value]) if result == OK else "NOT INSTALLED / " + error_string(result)
	_refresh_upgrades()


func _recover_upgrades() -> void:
	var station: ServiceStation = _live_station()
	if station == null:
		return
	var result: Error = station.recover_upgrades()
	(%UpgradeFeedback as Label).text = "Backup restored; capabilities rebuilt from saved IDs." if result == OK else "RECOVERY FAILED / " + error_string(result)
	_refresh_upgrades()
