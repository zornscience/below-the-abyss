class_name ExpeditionInterface
extends CanvasLayer
## Deliberate title/dock/story pages; ordinary radio uses the non-blocking queue.
var revision: ExpeditionRevision
var title_art: HalcyonDescent
var title_page: PanelContainer
var _title_margin: MarginContainer
var _covered_world: bool = false
var _world_was_visible: bool = true
var _wordmark: Label
var dock_page: PanelContainer
var radio_page: PanelContainer
var notifications: RadioNotifications
var _dock_body: VBoxContainer
var _title_body: VBoxContainer
var _radio_body: VBoxContainer
var _buttons: Array[Button] = []
var _story_back: Callable
var _dock_tab: String = "home"
var _scrolls: Dictionary = {}
var _tools: Dictionary = {}
func setup(owner_revision: ExpeditionRevision) -> void:
	revision = owner_revision
	layer = 80
	title_art = HalcyonDescent.new()
	add_child(title_art)
	title_page = _screen()
	title_page.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	_title_body = _content(title_page,true)
	_title_margin = title_page.get_child(0) as MarginContainer
	(_tools[title_page] as Control).hide()
	title_page.visibility_changed.connect(_title_visibility)
	get_viewport().size_changed.connect(_layout_title)
	revision.scene.settings.settings_changed.connect(_layout_title)
	dock_page = _screen()
	_dock_body = _content(dock_page,true)
	radio_page = _screen()
	_radio_body = _content(radio_page,true)
	dock_page.hide()
	radio_page.hide()
	UiDialogLayout.bind_panel(dock_page,Vector2(960,580))
	UiDialogLayout.bind_panel(radio_page,Vector2(760,480))
	show_title()
	_title_visibility()
	notifications = RadioNotifications.new()
	add_child(notifications)
	notifications.setup(revision)
func _title_visibility() -> void:
	title_art.visible = title_page.visible
	var world: Node2D = revision.scene.get_node("WorldRoot") as Node2D
	if title_page.visible and not _covered_world:
		_world_was_visible = world.visible
		world.hide()
		_covered_world = true
	elif not title_page.visible and _covered_world:
		world.visible = _world_was_visible
		_covered_world = false

func _screen() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.theme = preload("res://resources/balance/instrument_theme.tres")
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color("081923")
	panel.add_theme_stylebox_override("panel",box)
	add_child(panel)
	return panel
func _content(panel: PanelContainer, scroll_tools: bool = false) -> VBoxContainer:
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,18)
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
		add_child(child)
		if child is CanvasItem: child.hide()
		child.queue_free()
func _label(column: Container, text: String, role: StringName = &"body") -> Label:
	var label: Label = Label.new()
	label.text = text
	UiTypography.style(label,role)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)
	return label
func _button(column: Container, text: String, callback: Callable, disabled: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text
	UiTypography.style(button,&"dialog_button")
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled
	button.pressed.connect(callback)
	column.add_child(button)
	if not disabled: _buttons.append(button)
	return button
func _focus() -> void:
	for tools: Control in _tools.values():
		for child: Node in tools.get_children():
			while child in _buttons: _buttons.erase(child)
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
	_label(_title_body,"B E L O W   T H E",&"body")
	_wordmark = _label(_title_body,"ABYSS",&"title")
	_wordmark.add_theme_color_override("font_color",Color("d2d6c5"))
	_label(_title_body,"A scientific voyage into the unknown",&"body")
	var divider: HSeparator = HSeparator.new()
	_title_body.add_child(divider)
	var controls: VBoxContainer = VBoxContainer.new()
	_title_body.add_child(controls)
	var available: bool = revision.scene.saves != null and revision.scene.saves.has_checkpoint()
	_button(controls,revision.scene.chapter.primary_title() if revision.scene.chapter!=null else ("Continue expedition" if available else "Begin expedition"),revision.start_from_title,not revision.can_write()).name = "Begin"
	_button(controls,"Options",show_options).name = "TitleOptions"
	_button(controls,"Quit",func() -> void: get_tree().quit()).name = "TitleQuit"
	if revision.scene.chapter!=null and revision.scene.chapter.can_offer_prototype():
		_button(_title_body,"Prototype expedition / legacy checkpoint",revision.scene.chapter.start_prototype,not revision.can_write()).name = "PrototypeExpedition"
	_label(_title_body,"HALCYON / MERIDIAN DEEP INSTITUTE",&"body")
	if not revision.can_write():
		_label(_title_body,"Existing save needs recovery. Your files have been preserved.")
		_button(_title_body,"Recover checkpoint",func() -> void:
			revision.scene._recover_expedition()
			show_title()).name = "RecoverCheckpoint"
	_layout_title()
	_focus()
func show_options() -> void:
	_clear(_title_body)
	_wordmark = null
	_label(_title_body,"OPTIONS",&"heading")
	_button(_title_body,"Input controls",func() -> void: revision.open_option("input"))
	_button(_title_body,"Audio",func() -> void: revision.open_option("audio"))
	_button(_title_body,"Accessibility",func() -> void: revision.open_option("accessibility")).name = "TitleAccessibility"
	_button(_title_body,"Help & tutorials",func() -> void: revision.open_option("help"))
	_button(_title_body,"Back",show_title).name = "TitleBack"
	_layout_title()
	_focus()
func _layout_title() -> void:
	if _title_margin==null: return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var width: float = minf(420,viewport.x*0.45)
	var left: float = maxf(24,viewport.x*0.065)
	_title_margin.add_theme_constant_override("margin_left",roundi(left))
	_title_margin.add_theme_constant_override("margin_right",roundi(viewport.x-left-width))
	_title_margin.add_theme_constant_override("margin_top",roundi(maxf(24,viewport.y*0.12)))
	_title_margin.add_theme_constant_override("margin_bottom",24)
	var preferences: Dictionary = revision.scene.settings.snapshot().accessibility
	title_art.apply_preferences(preferences)
	if is_instance_valid(_wordmark):
		UiTypography.apply(_wordmark,String(preferences.ui_scale))
	for child: Node in _title_body.find_children("*","Button",true,false):
		var button: Button = child as Button
		UiTypography.style(button,&"menu_button")
		UiTypography.apply(button,String(preferences.ui_scale))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var normal: StyleBoxFlat = StyleBoxFlat.new()
		normal.bg_color = Color("030c12") if preferences.high_contrast else Color(0.025,0.075,0.1,0.78)
		normal.border_color = Color("a9c5cb") if preferences.high_contrast else Color("3b7078")
		normal.border_width_bottom = 2 if preferences.high_contrast else 1
		normal.content_margin_left = 16
		normal.content_margin_right = 16
		normal.content_margin_top = 10
		normal.content_margin_bottom = 10
		button.add_theme_stylebox_override("normal",normal)
		button.set_meta("a11y_style",[true,normal])
		var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color("193e4d")
		hover.border_color = Color("b5a779")
		hover.border_width_left = 3
		button.add_theme_stylebox_override("hover",hover)
		button.add_theme_stylebox_override("pressed",hover)

func show_dock(tab: String = "home") -> void:
	_dock_tab = tab
	var canonical: bool = revision.scene.chapter!=null and revision.scene.chapter.active
	(_tools[dock_page] as Control).visible = tab!="home" or canonical
	_clear(_dock_body)
	dock_page.show()
	_label(_dock_body,("HALCYON STATION  /  " if canonical else "SHELF BASE  /  ")+{"home":"OPERATIONS","technology":"RESEARCH TECHNOLOGY","logs":"EXPEDITION LOG" if canonical else "DECODED RECORDS","radio":"RADIO ARCHIVE"}[tab],&"heading")
	if tab=="home":
		var art: TextureRect = TextureRect.new()
		art.texture = HalcyonDescent.STATION
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.custom_minimum_size.y = (100 if get_viewport().get_visible_rect().size.y<700 else 160) if canonical else clampf(get_viewport().get_visible_rect().size.y*0.46,220,380)
		_dock_body.add_child(art)
		_label(_dock_body,revision.docking_report)
		var row: HBoxContainer = HBoxContainer.new()
		_dock_body.add_child(row)
		_button(row,"Research technology",func() -> void: show_dock("technology")).name = "Technology"
		_button(row,"Expedition log" if canonical else "Expedition logs",func() -> void: show_dock("logs")).name = "DockLogs"
		if canonical: _button(_dock_body,"First expedition debrief",revision.scene.chapter.show_debrief).name = "ChapterDebrief"
		_button(row,"Radio archive",func() -> void: show_dock("radio"))
		_button(_dock_body,"Depart station",revision.undock).name = "Depart"
	elif tab=="technology":
		_label(_dock_body,"%d RESEARCH POINTS AVAILABLE  /  %d EARNED" % [CampaignData.available(revision.campaign),CampaignData.earned(revision.campaign)],&"heading")
		if canonical: _label(_dock_body,"RESEARCH XP %d · BONUS POINTS %d/%d" % [ResearchExperienceData.total(revision.campaign.science),ResearchExperienceData.points(revision.campaign.science),ResearchExperienceData.RULES.maximum_extra_points],&"body")
		var xp_rules: ResearchExperienceRules = ResearchExperienceData.RULES
		_label(_dock_body,("First species scans earn %d XP; new scientific studies earn %d XP. Each %d XP adds one research point, limited to %d extra points in this chapter. Existing scans never award XP again. Reassignment is free while docked." % [xp_rules.species_xp,xp_rules.study_xp,xp_rules.xp_per_point,xp_rules.maximum_extra_points]) if canonical else "A finite four-point research budget. Assign across two branches; reassign freely while docked. Each rank costs one point.")
		var branches: HBoxContainer = HBoxContainer.new()
		_dock_body.add_child(branches)
		for branch: String in ["sonar","hull"]:
			var column: VBoxContainer = VBoxContainer.new()
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			branches.add_child(column)
			_label(column,"ACOUSTIC ARRAY" if branch=="sonar" else "PRESSURE HULL",&"section")
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
		_label(_dock_body,revision.scene.chapter.log_text() if canonical else (revision.decoded_text() if revision.campaign.decoded else "No decoded expedition recorder. Recover the encrypted logs with a scientific scan, then return to base. Your other research remains in Map → Research."),&"body")
		_button(_dock_body,"Back to operations",func() -> void: show_dock()).name = "BackOperations"
	else:
		_label(_dock_body,revision.scene.chapter.log_text() if canonical else revision.archive_text(),&"body")
		_button(_dock_body,"Back to operations",func() -> void: show_dock()).name = "BackOperations"
	_focus()
func _assign(branch: String, difference: int) -> void:
	revision.assign(branch,difference)
	show_dock("technology")
func _respec() -> void:
	revision.respec()
	show_dock("technology")
func show_radio(id: String, body: String, _offer: bool) -> void:
	notifications.enqueue(id,body)
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
	if radio_page.visible:
		if _story_back.is_valid(): _story_back.call()
		else: revision.defer_transmission()
	elif dock_page.visible:
		if _dock_tab=="home": revision.undock()
		else: show_dock()
	else: show_title()

func show_story_page(title: String, text: String, action: String, callback: Callable, id: StringName, back: Callable) -> void:
	_story_back = back
	_clear(_radio_body)
	radio_page.show()
	_label(_radio_body,title,&"heading")
	_label(_radio_body,text,&"body")
	_button(_radio_body,action,callback).name = id
	_button(_radio_body,"Back",back).name = "StoryBack"
	_focus()
	((_tools[radio_page] as Control).get_child(0) as Control).grab_focus()
	_queue_story_read.call_deferred()
func add_story_option(text: String, callback: Callable, id: StringName) -> void:
	_button(_radio_body,text,callback).name = id
	_focus()
	((_tools[radio_page] as Control).get_child(0) as Control).grab_focus()
	_queue_story_read.call_deferred()
func add_story_notice(text: String) -> void:
	_label(_radio_body,text)

func _queue_story_read() -> void:
	if not get_tree().process_frame.is_connected(_reset_story_read): get_tree().process_frame.connect(_reset_story_read,CONNECT_ONE_SHOT)
func _reset_story_read() -> void:
	var focus: Control = get_viewport().gui_get_focus_owner()
	if radio_page.visible and _story_back.is_valid() and focus!=null and (_tools[radio_page] as Control).is_ancestor_of(focus):
		(_scrolls[radio_page] as ScrollContainer).scroll_vertical = 0
