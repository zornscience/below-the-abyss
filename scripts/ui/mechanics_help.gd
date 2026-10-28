class_name MechanicsHelp
extends Control
signal close_requested
var _scene: ShelfPrototype
var _toggle: Button
var _status: Label
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = preload("res://resources/balance/instrument_theme.tres")
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("030c12")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var back: Button = Button.new()
	back.text = "Return to expedition"
	content.add_child(back)
	back.pressed.connect(_close)
	_toggle = Button.new()
	content.add_child(_toggle)
	_toggle.pressed.connect(func() -> void:
		var result: Error = _scene.tutorial.toggle()
		_toggle.text = "Tutorial messages: " + ("ON" if _scene.settings.snapshot().onboarding.enabled else "OFF")
		_status.text = "Preference saved." if result == OK else "Could not save preference; existing choice retained.")
	var controls: Array[Button] = [back,_toggle]
	for id: String in SettingsStore.TUTORIAL_IDS:
		var button: Button = Button.new()
		button.text = TutorialDirector.TEXT[id][0]
		content.add_child(button)
		var detail: Label = Label.new()
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.hide()
		content.add_child(detail)
		button.pressed.connect(func() -> void:
			detail.text = _scene.tutorial._body(id)
			detail.visible = not detail.visible)
		controls.append(button)
	_status = Label.new()
	content.add_child(_status)
	for index: int in range(controls.size()):
		for property: String in ["focus_next","focus_neighbor_bottom"]: controls[index].set(property,controls[index].get_path_to(controls[(index+1)%controls.size()]))
		for property: String in ["focus_previous","focus_neighbor_top"]: controls[index].set(property,controls[index].get_path_to(controls[posmod(index-1,controls.size())]))
	hide()
func present(scene: ShelfPrototype) -> void:
	_scene = scene
	_toggle.text = "Tutorial messages: " + ("ON" if scene.settings.snapshot().onboarding.enabled else "OFF")
	show()
	_toggle.grab_focus()
func _close() -> void:
	hide()
	close_requested.emit()
func _input(event: InputEvent) -> void:
	if visible and not event.is_echo() and InputBindings.is_menu_back(event):
		get_viewport().set_input_as_handled()
		_close()
