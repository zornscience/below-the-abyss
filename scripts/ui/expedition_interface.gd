class_name ExpeditionInterface
extends CanvasLayer
## Title, dock and radio use discrete pages with fixed recovery controls.
var revision: ExpeditionRevision
var title_page: PanelContainer
var dock_page: PanelContainer
var radio_page: PanelContainer
var _dock_body: VBoxContainer
var _title_body: VBoxContainer
var _radio_body: VBoxContainer
var _buttons: Array[Button] = []
var _dock_tab: String = "home"
var _scrolls: Dictionary = {}
var _tools: Dictionary = {}
func setup(owner_revision: ExpeditionRevision) -> void:
	revision = owner_revision
	layer = 80
	title_page = _screen()
	_title_body = _content(title_page)
	dock_page = _screen()
	_dock_body = _content(dock_page,true)
	radio_page = _screen()
	_radio_body = _content(radio_page,true)
	dock_page.hide()
	radio_page.hide()
	show_title()
func _screen() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.theme = preload("res://resources/balance/instrument_theme.tres")
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color("06121e")
	panel.add_theme_stylebox_override("panel",box)
	add_child(panel)
	return panel
func _content(panel: PanelContainer, scroll_tools: bool = false) -> VBoxContainer:
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	panel.add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var frame: VBoxContainer = VBoxContainer.new()
	margin.add_child(frame)
	frame.add_child(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scrolls[panel] = scroll
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",12)
	scroll.add_child(column)
	if scroll_tools:
		var footer: HBoxContainer = HBoxContainer.new()
		frame.add_child(footer)
		_tools[panel] = footer
		for direction: int in [-1,1]:
			var button: Button = Button.new()
			button.text = "Text ↑" if direction<0 else "Text ↓"
			button.custom_minimum_size = Vector2(100,40)
			button.pressed.connect(func() -> void: scroll.scroll_vertical += direction*140)
			footer.add_child(button)
	return column
func _clear(column: VBoxContainer) -> void:
	_buttons.clear()
	for child: Node in column.get_children():
		column.remove_child(child)
		child.queue_free()
func _label(column: Container, text: String, font: int = 18) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)
	return label
func _button(column: Container, text: String, callback: Callable, disabled: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled
	button.pressed.connect(callback)
	column.add_child(button)
	if not disabled: _buttons.append(button)
	return button
func _focus() -> void:
	var panel: Control = radio_page if radio_page.visible else (dock_page if dock_page.visible else title_page)
	if _tools.has(panel) and (_tools[panel] as Control).visible:
		for child: Node in (_tools[panel] as Control).get_children(): _buttons.append(child as Button)
	for index: int in range(_buttons.size()):
		var button: Button = _buttons[index]
		for property: String in ["focus_next","focus_neighbor_bottom","focus_neighbor_right"]: button.set(property,button.get_path_to(_buttons[(index+1)%_buttons.size()]))
		for property: String in ["focus_previous","focus_neighbor_top","focus_neighbor_left"]: button.set(property,button.get_path_to(_buttons[posmod(index-1,_buttons.size())]))
	if not _buttons.is_empty(): _buttons[0].grab_focus()
func show_title() -> void:
	_clear(_title_body)
	title_page.show()
	var title: Label = _label(_title_body,"B E L O W   T H E\nA B Y S S",56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color",Color("d5e6d7"))
	var portrait: SubmarinePortrait = SubmarinePortrait.new()
	portrait.custom_minimum_size.y = 210
	_title_body.add_child(portrait)
	var controls: HBoxContainer = HBoxContainer.new()
	_title_body.add_child(controls)
	var available: bool = revision.scene.saves != null and revision.scene.saves.has_checkpoint()
	_button(controls,"Continue expedition" if available else "Begin expedition",revision.start,not revision.can_write()).name = "Begin"
	_button(controls,"Options",show_options)
	_button(controls,"Quit",func() -> void: get_tree().quit())
	_label(_title_body,"A scientific voyage into the unknown",18).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not revision.can_write():
		_label(_title_body,"Existing save needs recovery. Your files have been preserved.")
		_button(_title_body,"Recover checkpoint",func() -> void:
			revision.scene._recover_expedition()
			show_title())
	_focus()
func show_options() -> void:
	_clear(_title_body)
	_label(_title_body,"OPTIONS",32)
	_button(_title_body,"Input controls",func() -> void: revision.open_option("input"))
	_button(_title_body,"Audio",func() -> void: revision.open_option("audio"))
	_button(_title_body,"Accessibility",func() -> void: revision.open_option("accessibility"))
	_button(_title_body,"Help & tutorials",func() -> void: revision.open_option("help"))
	_button(_title_body,"Back",show_title)
	_focus()
func show_dock(tab: String = "home") -> void:
	_dock_tab = tab
	(_tools[dock_page] as Control).visible = tab!="home"
	_clear(_dock_body)
	dock_page.show()
	_label(_dock_body,"SHELF BASE  /  "+{"home":"OPERATIONS","technology":"RESEARCH TECHNOLOGY","logs":"DECODED RECORDS","radio":"RADIO ARCHIVE"}[tab],28)
	if tab=="home":
		var art: StationInterior = StationInterior.new()
		art.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y*0.46,220,380)
		_dock_body.add_child(art)
		_label(_dock_body,revision.docking_report)
		var row: HBoxContainer = HBoxContainer.new()
		_dock_body.add_child(row)
		_button(row,"Research technology",func() -> void: show_dock("technology")).name = "Technology"
		_button(row,"Expedition logs",func() -> void: show_dock("logs"))
		_button(row,"Radio archive",func() -> void: show_dock("radio"))
		_button(_dock_body,"Depart station",revision.undock).name = "Depart"
	elif tab=="technology":
		_label(_dock_body,"%d RESEARCH POINTS AVAILABLE  /  %d EARNED" % [CampaignData.available(revision.campaign),CampaignData.earned(revision.campaign)],24)
		_label(_dock_body,"A finite four-point research budget. Assign across two branches; reassign freely while docked. Each rank costs one point.")
		var branches: HBoxContainer = HBoxContainer.new()
		_dock_body.add_child(branches)
		for branch: String in ["sonar","hull"]:
			var column: VBoxContainer = VBoxContainer.new()
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			branches.add_child(column)
			_label(column,"ACOUSTIC ARRAY" if branch=="sonar" else "PRESSURE HULL",22)
			var values: PackedFloat32Array = revision.tree.sonar_radii if branch=="sonar" else revision.tree.hull_ratings
			var rank: int = int(revision.campaign.ranks[branch])
			var diagram: ResearchTreeIllustration = ResearchTreeIllustration.new()
			diagram.text_scale = float(UiAccessibility.SCALE[revision.scene.settings.snapshot().accessibility.ui_scale])
			diagram.branch = branch
			diagram.rank = rank
			diagram.values = values
			column.add_child(diagram)
			_button(column,"Assign next rank",_assign.bind(branch,1),rank>=3 or CampaignData.available(revision.campaign)<=0).name = branch+"Assign"
			_button(column,"Refund last rank",_assign.bind(branch,-1),rank<=0).name = branch+"Refund"
		_button(_dock_body,"Reassign all points",_respec)
		_label(_dock_body,revision.feedback)
		_button(_dock_body,"Back to operations",func() -> void: show_dock()).name = "BackOperations"
	elif tab=="logs":
		_label(_dock_body,revision.decoded_text() if revision.campaign.decoded else "No decoded expedition recorder. Recover the encrypted logs with a scientific scan, then return to base. Your other research remains in Map → Research.",20)
		_button(_dock_body,"Back to operations",func() -> void: show_dock()).name = "BackOperations"
	else:
		_label(_dock_body,revision.archive_text(),20)
		_button(_dock_body,"Back to operations",func() -> void: show_dock()).name = "BackOperations"
	_focus()
func _assign(branch: String, difference: int) -> void:
	revision.assign(branch,difference)
	show_dock("technology")
func _respec() -> void:
	revision.respec()
	show_dock("technology")
func show_radio(id: String, body: String, offer: bool) -> void:
	_clear(_radio_body)
	radio_page.show()
	_label(_radio_body,"INCOMING TRANSMISSION  /  SHELF BASE",28)
	_label(_radio_body,body,24)
	_button(_radio_body,"Accept investigation" if offer else "Acknowledge",func() -> void: revision.accept_transmission(id,offer)).name = "AcceptTransmission"
	_button(_radio_body,"Read later",revision.defer_transmission)
	_focus()
func modal() -> bool:
	return title_page.visible or dock_page.visible or radio_page.visible
func _input(event: InputEvent) -> void:
	if modal() and event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP,KEY_PAGEDOWN]:
		var page: Control = radio_page if radio_page.visible else (dock_page if dock_page.visible else title_page)
		(_scrolls[page] as ScrollContainer).scroll_vertical += -200 if event.keycode==KEY_PAGEUP else 200
		get_viewport().set_input_as_handled()
		return
	if not modal() or event.is_echo() or not InputBindings.is_menu_back(event): return
	get_viewport().set_input_as_handled()
	if radio_page.visible: revision.defer_transmission()
	elif dock_page.visible:
		if _dock_tab=="home": revision.undock()
		else: show_dock()
	else: show_title()
