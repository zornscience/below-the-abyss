class_name BloomChoicePanel
extends CanvasLayer
## Nonnumeric, mute-safe story presentation with persistent footer/recovery controls.
var encounter: LightBloomEncounter
var page: PanelContainer
var body: VBoxContainer
var scroll: ScrollContainer
var _buttons: Array[Button] = []
var _response: bool = false
func setup(owner_encounter: LightBloomEncounter) -> void:
	encounter = owner_encounter
	layer = 85
	page = PanelContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.theme = preload("res://resources/balance/instrument_theme.tres")
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("081923")
	page.add_theme_stylebox_override("panel",style)
	add_child(page)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	page.add_child(margin)
	var frame: VBoxContainer = VBoxContainer.new()
	margin.add_child(frame)
	scroll = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",14)
	scroll.add_child(body)
	var footer: HBoxContainer = HBoxContainer.new()
	frame.add_child(footer)
	for direction: int in [-1,1]:
		var button: Button = Button.new()
		button.text = "Text ↑" if direction<0 else "Text ↓"
		button.custom_minimum_size = Vector2(100,42)
		button.pressed.connect(func() -> void: scroll.scroll_vertical += direction*140)
		footer.add_child(button)
	page.set_meta("footer",footer)
	page.hide()
func visible_page() -> bool:
	return page.visible
func hide_page() -> void:
	page.hide()
func _clear() -> void:
	_buttons.clear()
	for child: Node in body.get_children():
		body.remove_child(child)
		# Keep retired controls owned until the pressed callback can safely return.
		add_child(child)
		if child is CanvasItem: child.hide()
		child.queue_free()
func _label(text: String, size: int = 22) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",size)
	body.add_child(label)
	return label
func _button(id: String, text: String, callback: Callable, disabled: bool = false) -> void:
	var button: Button = Button.new()
	button.name = id
	button.text = text
	button.custom_minimum_size.y = 50
	button.disabled = disabled
	button.pressed.connect(callback)
	body.add_child(button)
	if not disabled: _buttons.append(button)
func _portrait() -> void:
	var space: Control = Control.new()
	space.custom_minimum_size.y = 120
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(space)
	var bloom: LightBloomVisual = LightBloomVisual.new()
	space.add_child(bloom)
	bloom.specimen_view = true
	bloom.scale = Vector2.ONE*1.5
	bloom.position = Vector2(105,65)
	var prefs: Dictionary = encounter.scene.settings.snapshot().accessibility
	bloom.reduced_effects = prefs.reduced_motion or prefs.reduced_flashing
	bloom.set_outcome(encounter.scene.story.has_decision(LightBloomEncounter.COLLECT),encounter.scene.story.has_decision(LightBloomEncounter.OBSERVE),_response)
func show_choice() -> void:
	_response = false
	_clear()
	page.show()
	_label("LIGHT-BLOOM PLANKTON",30)
	_portrait()
	_label("Bioluminescent plankton forms a precise spiral, then scatters. Dr. Okafor, the station biologist, asks for a scan. Director Crane asks for a bottled sample. Bottling kills the sampled bloom.")
	if not encounter.identified(): _label("Identify the bloom with sonar before choosing how to study it.")
	if encounter.scene.saves==null or not encounter.scene.saves.can_write(): _label("Checkpoint unavailable. Recover the existing save before making a decision.")
	_button("ObserveBloom",encounter.scene.story.definition(LightBloomEncounter.OBSERVE).action_text,_observe,not encounter.can_choose())
	_button("CollectBloom",encounter.scene.story.definition(LightBloomEncounter.COLLECT).action_text,_collect,not encounter.can_choose())
	_button("LeaveBloom","Leave for now",encounter.leave)
	_focus()
func show_response(text: String) -> void:
	_response = true
	_clear()
	page.show()
	_label("BLOOM LEFT UNHARMED" if encounter.scene.story.has_decision(LightBloomEncounter.OBSERVE) else "SPECIMEN BOTTLED · BLOOM EXTINGUISHED",28)
	_label("Wick · onboard AI / Okafor and Crane · Halcyon radio",18)
	_portrait()
	_label(text)
	_button("ReturnFromBloom","Return to piloting",encounter.leave)
	_focus()
func _observe() -> void:
	var result: Error = encounter.choose_observe()
	if result!=OK and visible_page(): _label("Scan unavailable. No decision was committed.")
func _collect() -> void:
	var result: Error = encounter.choose_collect()
	if result!=OK:
		_label("Decision not saved. Existing progress is preserved; recover or retry the checkpoint.")
func _focus() -> void:
	for node: Node in (page.get_meta("footer") as Control).get_children(): _buttons.append(node as Button)
	for index: int in range(_buttons.size()):
		for property: String in ["focus_next","focus_neighbor_bottom","focus_neighbor_right"]: _buttons[index].set(property,_buttons[index].get_path_to(_buttons[(index+1)%_buttons.size()]))
		for property: String in ["focus_previous","focus_neighbor_top","focus_neighbor_left"]: _buttons[index].set(property,_buttons[index].get_path_to(_buttons[posmod(index-1,_buttons.size())]))
	if not _buttons.is_empty():
		(_buttons[-2] if _response else _buttons[0]).grab_focus()
	scroll.set_deferred("scroll_vertical",0)
	if _response: _queue_read_scroll.call_deferred()
func _queue_read_scroll() -> void:
	# Bound one-shot connections are disconnected if this panel is freed.
	if not get_tree().process_frame.is_connected(_reset_read_scroll):
		get_tree().process_frame.connect(_reset_read_scroll,CONNECT_ONE_SHOT)
func _reset_read_scroll() -> void:
	# Accessibility font reflow and focus-follow finish after the initial layout.
	var footer: Control = page.get_meta("footer") as Control
	var focus: Control = get_viewport().gui_get_focus_owner()
	if page.visible and _response and focus!=null and footer.is_ancestor_of(focus):
		scroll.scroll_vertical = 0
func refresh_comfort() -> void:
	if body==null: return
	var prefs: Dictionary = encounter.scene.settings.snapshot().accessibility
	for node: Node in body.find_children("*","Node2D",true,false):
		if node is LightBloomVisual:
			node.reduced_effects = prefs.reduced_motion or prefs.reduced_flashing
			if node.reduced_effects: node.reaction = 0.0
func _input(event: InputEvent) -> void:
	if not visible_page(): return
	if event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP,KEY_PAGEDOWN]:
		scroll.scroll_vertical += -180 if event.keycode==KEY_PAGEUP else 180
		get_viewport().set_input_as_handled()
	elif not event.is_echo() and InputBindings.is_menu_back(event):
		encounter.leave()
		get_viewport().set_input_as_handled()
