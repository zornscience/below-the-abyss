class_name AccessibilityPanel
extends Control
## Live preview, explicit Save, scoped defaults and cancellation.
signal close_requested
var settings: SettingsStore
var settings_path: String
var _original: Dictionary
var darkness_picker: OptionButton
var scale_picker: OptionButton
var toggles: Dictionary[String, CheckButton] = {}
var status: Label
var save_button: Button
var reset_button: Button
var close_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = preload("res://resources/balance/instrument_theme.tres")
	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("030b10")
	add_child(backdrop)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_label(content, "ACCESSIBILITY / Controls and visual comfort",&"heading")
	_label(content, "↑↓ / Tab / D-pad: choose · Enter / A: select · Esc / B: discard unsaved edits",&"body")
	scale_picker = OptionButton.new()
	for item: String in ["Compact / 90% (minimum 14 px)", "Standard / 100%", "Large / 125%"]:
		scale_picker.add_item(item)
	content.add_child(scale_picker)
	scale_picker.item_selected.connect(func(index: int) -> void:
		var next: Dictionary = settings.snapshot().accessibility
		next.ui_scale = ["compact", "standard", "large"][index]
		settings.set_accessibility(next))
	darkness_picker = OptionButton.new()
	darkness_picker.add_item("Twilight darkness / Standard")
	darkness_picker.add_item("Twilight darkness / Reduced")
	content.add_child(darkness_picker)
	darkness_picker.item_selected.connect(func(index: int) -> void:
		var next: Dictionary = settings.snapshot().accessibility
		next.darkness = "reduced" if index==1 else "standard"
		settings.set_accessibility(next))
	var labels: Dictionary = {"reduced_flashing": "Reduced flashing / softer sonar highlights", "reduced_particles": "Disable decorative particles",
		"reduced_motion": "Reduced motion / static propeller, motes and parallax", "high_contrast": "High contrast instruments and menus"}
	for key: String in labels:
		var toggle: CheckButton = CheckButton.new()
		toggle.text = labels[key]
		content.add_child(toggle)
		toggles[key] = toggle
		toggle.toggled.connect(func(value: bool) -> void:
			var next: Dictionary = settings.snapshot().accessibility
			next[key] = value
			settings.set_accessibility(next))
	content.move_child(darkness_picker,content.get_child_count()-1)
	_label(content, "No camera shake or flashing alarm sequence is authored. Sonar timing, warnings and movement stay active with comfort options enabled. Menu recovery controls remain fixed after gameplay remapping.",&"body")
	save_button = Button.new()
	save_button.text = "Save accessibility preferences"
	content.add_child(save_button)
	save_button.pressed.connect(_save)
	reset_button = Button.new()
	reset_button.text = "Restore accessibility defaults only"
	content.add_child(reset_button)
	reset_button.pressed.connect(func() -> void:
		settings.set_accessibility(SettingsStore.default_accessibility())
		_refresh())
	close_button = Button.new()
	close_button.text = "Return / discard unsaved edits"
	content.add_child(close_button)
	close_button.pressed.connect(cancel)
	status = _label(content, "Preview changes here; Save keeps them across restarts.",&"body")
	var controls: Array[Control] = [scale_picker]
	for toggle: CheckButton in toggles.values():
		controls.append(toggle)
	controls.append(darkness_picker)
	controls.append_array([save_button, reset_button, close_button])
	for index: int in range(controls.size()):
		for property: String in ["focus_next", "focus_neighbor_bottom"]:
			controls[index].set(property, controls[index].get_path_to(controls[(index + 1) % controls.size()]))
		for property: String in ["focus_previous", "focus_neighbor_top"]:
			controls[index].set(property, controls[index].get_path_to(controls[posmod(index - 1, controls.size())]))
	hide()


func _label(parent: Node, text: String, role: StringName = &"body") -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTypography.style(label,role)
	parent.add_child(label)
	return label


func present(value: SettingsStore, path: String) -> void:
	settings = value
	settings_path = path
	_original = settings.snapshot().accessibility
	_refresh()
	status.text = "Preview changes here; Save keeps them across restarts." if settings.last_load_result in [OK, ERR_FILE_NOT_FOUND] else "Preferences could not load (%s). Valid preferences retained; explicit Save preserves rejected bytes in .invalid." % error_string(settings.last_load_result)
	show()
	scale_picker.grab_focus()


func _refresh() -> void:
	var value: Dictionary = settings.snapshot().accessibility
	darkness_picker.select(1 if value.get("darkness","standard")=="reduced" else 0)
	scale_picker.select(["compact", "standard", "large"].find(value.ui_scale))
	for key: String in toggles:
		toggles[key].set_pressed_no_signal(bool(value[key]))


func _save() -> void:
	var result: Error = settings.save_settings(settings_path)
	if result == OK:
		_original = settings.snapshot().accessibility
	status.text = "Accessibility saved." if result == OK else "Not saved: %s. Preview remains unsaved; original preferences retained on Return." % error_string(result)


func cancel() -> void:
	settings.set_accessibility(_original)
	hide()
	close_requested.emit()


func _input(event: InputEvent) -> void:
	if visible and not event.is_echo() and InputBindings.is_menu_back(event):
		get_viewport().set_input_as_handled()
		cancel()
