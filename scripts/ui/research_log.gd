class_name ResearchLog
extends Control
## Completed records only. No catalogue/undiscovered titles enter this page.

signal close_requested
var registry: ResearchRegistry
var store: ResearchStore


func _ready() -> void:
	(%ScrollResearchUp as Button).pressed.connect(func() -> void: (%DetailScroll as ScrollContainer).scroll_vertical -= 100)
	(%ScrollResearchDown as Button).pressed.connect(func() -> void: (%DetailScroll as ScrollContainer).scroll_vertical += 100)
	(%CloseResearch as Button).pressed.connect(func() -> void: close_requested.emit())
	(%RetryResearch as Button).pressed.connect(func() -> void: store.retry_save(registry))
	(%RecoverResearch as Button).pressed.connect(func() -> void: store.recover_backup(registry))


func setup(value: ResearchRegistry, persistence: ResearchStore) -> void:
	registry = value
	store = persistence
	registry.records_changed.connect(refresh)
	store.status_changed.connect(_status)
	refresh()


func refresh() -> void:
	var list: VBoxContainer = %ResearchEntries
	for child: Node in list.get_children():
		list.remove_child(child)
		child.free()
	var controls: Array[Control] = [%CloseResearch, %RetryResearch, %RecoverResearch]
	var entries: Array[ScanDefinition] = registry.completed_records()
	(%ResearchDetail as Label).text = "No completed research. Discover a subject with sonar, approach and intentionally scan it."
	for entry: ScanDefinition in entries:
		var button: Button = Button.new()
		button.text = entry.title
		button.custom_minimum_size = Vector2(0, 44)
		button.clip_text = true
		button.pressed.connect(_select.bind(entry.stable_id))
		button.focus_entered.connect(_select.bind(entry.stable_id))
		list.add_child(button)
		controls.append(button)
	controls.append_array([%ScrollResearchUp, %ScrollResearchDown])
	for index: int in range(controls.size()):
		for property: String in ["focus_previous", "focus_neighbor_top", "focus_neighbor_left"]:
			controls[index].set(property, controls[index].get_path_to(controls[posmod(index - 1, controls.size())]))
		for property: String in ["focus_next", "focus_neighbor_bottom", "focus_neighbor_right"]:
			controls[index].set(property, controls[index].get_path_to(controls[(index + 1) % controls.size()]))
	if not entries.is_empty():
		_select(entries[0].stable_id)
	_status()


func _select(id: StringName) -> void:
	if registry.is_completed(id):
		var entry: ScanDefinition = registry.definition(id)
		(%ResearchDetail as Label).text = "%s\n%s / COMPLETED\n\n%s" % [entry.title, entry.classification.to_upper(), entry.description]


func _status() -> void:
	(%ResearchSaveStatus as Label).text = store.status


func present() -> void:
	show()
	(%CloseResearch as Button).grab_focus()


func _input(event: InputEvent) -> void:
	if visible and not event.is_echo() and ((event.is_action_pressed("open_map") and not InputBindings.is_menu_navigation(event)) \
		or InputBindings.is_menu_back(event)):
		get_viewport().set_input_as_handled()
		close_requested.emit()
