class_name ExplorationMap
extends Control
## Focusable text equivalent accompanies every graphical landmark.

signal research_requested
signal close_requested
var registry: DiscoveryRegistry
var store: DiscoveryStore
@onready var canvas: ExplorationMapCanvas = %MapCanvas


func _ready() -> void:
	(%OpenResearch as Button).pressed.connect(func() -> void: research_requested.emit())
	(%CloseMap as Button).pressed.connect(func() -> void: close_requested.emit())
	(%RetrySave as Button).pressed.connect(func() -> void: store.retry_save(registry))
	(%RecoverBackup as Button).pressed.connect(func() -> void: store.recover_backup(registry))


func setup(value: DiscoveryRegistry, persistence: DiscoveryStore) -> void:
	registry = value
	store = persistence
	registry.registry_changed.connect(refresh)
	store.status_changed.connect(_refresh_status)
	refresh()


func refresh() -> void:
	canvas.bounds = registry.survey_bounds()
	canvas.points = registry.discovered_points()
	var list: VBoxContainer = %LandmarkList
	for child: Node in list.get_children():
		list.remove_child(child)
		child.free()
	(%EmptyMap as Label).visible = canvas.points.is_empty()
	for index: int in range(canvas.points.size()):
		var point: PointOfInterest = canvas.points[index]
		var button: Button = Button.new()
		button.text = "%d / %s" % [index + 1, point.display_name]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 44
		button.clip_text = true
		button.focus_entered.connect(_select.bind(point.stable_id))
		button.pressed.connect(_select.bind(point.stable_id))
		list.add_child(button)
	var controls: Array[Control] = [%CloseMap, %RetrySave, %RecoverBackup]
	for child: Node in list.get_children():
		controls.append(child as Control)
	controls.append(%OpenResearch as Control)
	for index: int in range(controls.size()):
		var previous: Control = controls[posmod(index - 1, controls.size())]
		var next: Control = controls[(index + 1) % controls.size()]
		for property: String in ["focus_previous", "focus_neighbor_top", "focus_neighbor_left"]:
			controls[index].set(property, controls[index].get_path_to(previous))
		for property: String in ["focus_next", "focus_neighbor_bottom", "focus_neighbor_right"]:
			controls[index].set(property, controls[index].get_path_to(next))
	if visible:
		(%CloseMap as Button).grab_focus()
	canvas.queue_redraw()
	_refresh_status()


func _select(id: StringName) -> void:
	canvas.selected_id = id
	for point: PointOfInterest in canvas.points:
		if point.stable_id == id:
			(%SelectedLandmark as Label).text = "DISCOVERED / " + point.display_name
	canvas.queue_redraw()


func _refresh_status() -> void:
	(%DiscoverySaveStatus as Label).text = store.status


func present(position: Vector2, binding_hint: String) -> void:
	canvas.player_position = position
	(%MapHint as Label).text = "%s: map · Esc / B: close · arrows / D-pad / stick: select" % binding_hint
	show()
	canvas.queue_redraw()
	(%CloseMap as Button).grab_focus()


func _input(event: InputEvent) -> void:
	if visible and not event.is_echo() and ((event.is_action_pressed("open_map") and not InputBindings.is_menu_navigation(event)) \
		or InputBindings.is_menu_back(event)):
		get_viewport().set_input_as_handled()
		close_requested.emit()
