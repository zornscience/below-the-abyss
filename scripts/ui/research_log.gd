class_name ResearchLog
extends Control
## Completed records only. No catalogue/undiscovered titles enter this page.

signal close_requested
var entry_text_provider: Callable
var summary_provider: Callable
var summary: Label
var registry: ResearchRegistry
var store: ResearchStore


func _ready() -> void:
	summary = Label.new()
	UiTypography.style(summary,&"hud")
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	get_node("Margin/Content").add_child(summary)
	get_node("Margin/Content").move_child(summary,2)
	summary.hide()
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
	refresh_summary()
	var list: VBoxContainer = %ResearchEntries
	for child: Node in list.get_children():
		list.remove_child(child)
		child.free()
	var controls: Array[Control] = [%CloseResearch, %RetryResearch, %RecoverResearch]
	var entries: Array[ScanDefinition] = registry.completed_records()
	(%SubjectImage as TextureRect).hide()
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
	controls.append(%DetailScroll as Control)
	UiScrollReader.link(controls,%DetailScroll)
	if not entries.is_empty():
		_select(entries[0].stable_id)
	_status()

func refresh_summary() -> void:
	if summary==null: return
	summary.visible = summary_provider.is_valid()
	if summary_provider.is_valid(): summary.text = summary_provider.call()


func _select(id: StringName) -> void:
	if registry.is_completed(id):
		var entry: ScanDefinition = registry.definition(id)
		var image: TextureRect = %SubjectImage
		image.texture = entry.subject_texture
		if entry.subject_texture!=null and entry.subject_region.has_area():
			var clipped: AtlasTexture = AtlasTexture.new()
			clipped.atlas = entry.subject_texture
			clipped.region = entry.subject_region
			clipped.filter_clip = true
			image.texture = clipped
		image.visible = image.texture!=null
		(%ResearchDetail as Label).text = "%s\n%s / COMPLETED\n\n%s" % [entry.title, entry.classification.to_upper(), entry_text_provider.call(id,entry.description) if entry_text_provider.is_valid() else entry.description]


func _status() -> void:
	(%ResearchSaveStatus as Label).text = store.status


func present() -> void:
	refresh_summary()
	show()
	(%CloseResearch as Button).grab_focus()


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP,KEY_PAGEDOWN]:
		(%DetailScroll as UiScrollReader).handle_reading_input(event)
		get_viewport().set_input_as_handled()
		return
	if visible and not event.is_echo() and ((event.is_action_pressed("open_map") and not InputBindings.is_menu_navigation(event)) \
		or InputBindings.is_menu_back(event)):
		get_viewport().set_input_as_handled()
		close_requested.emit()
