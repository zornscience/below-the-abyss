class_name ExpeditionLog
extends Control
## Paused, rereadable narrative view; hidden entries never enter its controls/text.

signal close_requested
var narrative: NarrativeService
var _station: WeakRef
var _selected: StringName = &"shelf-station-briefing"
@onready var entry_list: VBoxContainer = %StoryEntries
@onready var detail: Label = %StoryDetail
@onready var feedback: Label = %StoryFeedback
@onready var begin_button: Button = %BeginSurvey
@onready var debrief_button: Button = %SubmitDebrief
@onready var close_button: Button = %CloseStory


func _ready() -> void:
	close_button.pressed.connect(func() -> void: close_requested.emit())
	begin_button.pressed.connect(_begin)
	debrief_button.pressed.connect(_debrief)
	(%StoryUp as Button).pressed.connect(func() -> void: (%StoryScroll as ScrollContainer).scroll_vertical -= 100)
	(%StoryDown as Button).pressed.connect(func() -> void: (%StoryScroll as ScrollContainer).scroll_vertical += 100)


func setup(service: NarrativeService) -> void:
	narrative = service
	service.log_changed.connect(refresh)
	refresh()


func present(station: ServiceStation = null) -> void:
	_station = weakref(station) if station != null else null
	feedback.text = "Simulation paused. Earlier discoveries and scans count. Read or skip; records stay available."
	if narrative.is_concluded():
		_selected = &"shelf-concluding-debrief"
	elif narrative.can_debrief() and station != null:
		_selected = &"shelf-safe-return"
	show()
	refresh()
	close_button.grab_focus()


func refresh() -> void:
	if narrative == null:
		return
	for child: Node in entry_list.get_children():
		entry_list.remove_child(child)
		child.free()
	var entries: Array[NarrativeEntry] = narrative.available_entries()
	for entry: NarrativeEntry in entries:
		var button: Button = Button.new()
		button.text = entry.title
		button.clip_text = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 44
		entry_list.add_child(button)
		button.pressed.connect(_select.bind(entry.stable_id))
		button.focus_entered.connect(_select.bind(entry.stable_id))
		if entry.stable_id == _selected:
			detail.text = entry.title + "\n\n" + entry.text
	(%StoryObjective as Label).text = narrative.guidance()
	var states: Dictionary = narrative.missions.snapshot()
	begin_button.disabled = not narrative.progress_allowed() or (states[String(NarrativeService.MAIN)].state != "available" and states[String(NarrativeService.SCIENCE)].state != "available")
	var station: ServiceStation = _station.get_ref() as ServiceStation if _station != null else null
	debrief_button.disabled = not narrative.progress_allowed() or station == null or not narrative.can_debrief()
	debrief_button.text = "Chapter acknowledged / saved" if narrative.is_concluded() else (
		"Submit expedition debrief" if station != null else "Dock at Shelf Base to debrief")
	var controls: Array[Control] = [close_button]
	for button: Button in [begin_button, debrief_button, %StoryUp, %StoryDown]:
		if not button.disabled:
			controls.append(button)
	for child: Node in entry_list.get_children():
		controls.append(child as Control)
	for index: int in range(controls.size()):
		for property: String in ["focus_next", "focus_neighbor_bottom", "focus_neighbor_right"]:
			controls[index].set(property, controls[index].get_path_to(controls[(index + 1) % controls.size()]))
		for property: String in ["focus_previous", "focus_neighbor_top", "focus_neighbor_left"]:
			controls[index].set(property, controls[index].get_path_to(controls[posmod(index - 1, controls.size())]))
	var focus: Control = get_viewport().gui_get_focus_owner()
	if visible and (focus == null or (focus is Button and (focus as Button).disabled)):
		close_button.grab_focus()


func _select(id: StringName) -> void:
	for entry: NarrativeEntry in narrative.available_entries():
		if entry.stable_id == id:
			_selected = id
			detail.text = entry.title + "\n\n" + entry.text
			(%StoryScroll as ScrollContainer).scroll_vertical = 0
			return


func _begin() -> void:
	var result: Error = narrative.begin_survey()
	feedback.text = "SURVEY ACCEPTED / Evidence and safe return use the existing mission board." if result == OK else "NOT ACCEPTED / " + error_string(result) + " · Use mission/checkpoint recovery if needed."
	refresh()
	if result == OK:
		_select(&"shelf-survey-orders")


func _debrief() -> void:
	var station: ServiceStation = _station.get_ref() as ServiceStation if _station != null else null
	var result: Error = narrative.debrief(station)
	feedback.text = "DEBRIEF SAVED / Both expedition acknowledgements recorded." if result == OK else "DEBRIEF NOT COMPLETE / " + error_string(result) + " · Saved partial acknowledgements remain; retry after recovery."
	refresh()
	if narrative.is_concluded():
		_select(&"shelf-concluding-debrief")


func _input(event: InputEvent) -> void:
	if visible and not event.is_echo() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("open_map")):
		get_viewport().set_input_as_handled()
		close_requested.emit()
