class_name RadioNotifications
extends Control
## Session-only delivery queue; campaign/research/narrative remain the durable authorities.
signal message_received(id: String)
const PREVIEW_SECONDS: float = 12.0
var revision: ExpeditionRevision
var pending: Array[String] = []
var texts: Dictionary[String,String] = {}
var sources: Dictionary[String,String] = {}
var expanded: bool = false
var selected: String = ""
var _remaining: float = 0.0
var playback: RadioPlayback = RadioPlayback.new()
var _playing: String = ""
var _reduced_motion: bool = false
var _previewed: Array[String] = []
var badge: Button
var panel: PanelContainer
var portrait: TextureRect
var _portrait_source: String = ""
var speaker: Label
var preview: Label
var transcript: Label
var scroll: ScrollContainer
var actions: VBoxContainer
var hint: Label
var _primary: HBoxContainer
var _navigation: HBoxContainer
var _controls: Array[Button] = []
var notice: String = ""
var _blocked_sonar_frame: int = -1
var accept: Button
var later: Button
var close_button: Button
var _choice: int = 0
func setup(value: ExpeditionRevision) -> void:
	revision = value
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = preload("res://resources/balance/instrument_theme.tres")
	badge = Button.new()
	badge.focus_mode = Control.FOCUS_NONE
	badge.pressed.connect(toggle)
	add_child(badge)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var content: VBoxContainer = VBoxContainer.new()
	panel.add_child(content)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation",12)
	content.add_child(header)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(56,72)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(portrait)
	speaker = Label.new()
	speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speaker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview = Label.new()
	for label: Label in [speaker,preview]:
		UiTypography.style(label,&"body")
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if label==speaker: header.add_child(label)
	scroll = UiScrollReader.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 120
	content.add_child(scroll)
	transcript = Label.new()
	UiTypography.style(transcript,&"body")
	transcript.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	transcript.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reading: VBoxContainer = VBoxContainer.new()
	reading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(reading)
	reading.add_child(preview)
	reading.add_child(transcript)
	actions = VBoxContainer.new()
	content.add_child(actions)
	hint = Label.new()
	UiTypography.style(hint,&"secondary")
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(hint)
	_primary = HBoxContainer.new()
	_navigation = HBoxContainer.new()
	actions.add_child(_primary)
	actions.add_child(_navigation)
	accept = _button("Accept",_accept,"AcceptTransmission")
	later = _button("Read later",defer_current,"ReadLaterRadio")
	close_button = _button("Close",collapse,"CloseRadio")
	_button("Next message",next_message,"NextRadio")
	panel.visibility_changed.connect(revision.scene._layout_tutorial)
	revision.scene.settings.settings_changed.connect(_comfort)
	_comfort()
	refresh()
func _button(text: String,callback: Callable,id: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.name = id
	button.custom_minimum_size.y = 40
	button.pressed.connect(callback)
	(_primary if id in ["AcceptTransmission","ReadLaterRadio","CloseRadio"] else _navigation).add_child(button)
	_controls.append(button)
	button.focus_entered.connect(func() -> void: _choice = _controls.find(button))
	return button
## Ids are lowercase words joined by hyphens, at most 64 characters. Producers do not need to
## register ids: an allow-list here once silently dropped nearly every Twilight message.
static func valid_id(id: String) -> bool:
	if id.is_empty() or id.length()>64: return false
	var pattern: RegEx = RegEx.new()
	pattern.compile("^[a-z0-9]+(-[a-z0-9]+)*$")
	return pattern.search(id)!=null
func enqueue(id: String,body: String,source: String = "Shelf Base",urgent: bool = false) -> void:
	if texts.has(id): return
	if not valid_id(id) or body.is_empty():
		push_warning("Radio message rejected, malformed id or empty body: "+id)
		return
	texts[id] = body
	sources[id] = source
	pending.append(id)
	message_received.emit(id)
	if selected.is_empty(): _next_preview()
	if urgent:
		selected = id
		if id not in _previewed: _previewed.append(id)
		_remaining = PREVIEW_SECONDS
	refresh()
func contains_message(id: String) -> bool:
	return id in pending
func _next_preview() -> void:
	selected = ""
	for id: String in pending:
		if id not in _previewed:
			selected = id
			_previewed.append(id)
			_remaining = PREVIEW_SECONDS
			return
func toggle() -> void:
	if expanded:
		collapse()
		return
	if pending.is_empty(): return
	if selected.is_empty(): selected = pending[0]
	expanded = true
	scroll.scroll_vertical = 0
	refresh()
	_choice = 0
	_focus_action()
func collapse() -> void:
	expanded = false
	_remaining = 0
	playback.elapsed = playback.typing_seconds()+playback.hold_seconds()
	release_focus()
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus!=null and is_ancestor_of(focus): focus.release_focus()
	refresh()
func defer_current() -> void:
	revision._defer_until = revision._clock+25.0
	collapse()
func remove_message(id: String) -> void:
	pending.erase(id)
	if selected==id:
		collapse()
		_next_preview()
	refresh()
func _accept() -> void:
	if selected in ExpeditionRevision.TRANSMISSIONS:
		revision.accept_transmission(selected,selected=="dispatch")
	else:
		# Buoy evidence is already durable; reading never creates another acknowledgement.
		remove_message(selected)
func refresh() -> void:
	if revision==null: return
	badge.text = "RADIO %d unread · %s" % [pending.size(),revision.scene.input_context.describe(&"open_radio").get_slice(" / ",0)]
	badge.visible = not pending.is_empty()
	panel.visible = not selected.is_empty() and (expanded or _remaining>0)
	if not texts.has(selected): return
	if _portrait_source!=sources[selected]:
		_portrait_source = sources[selected]
		portrait.texture = RadioPortraits.portrait(_portrait_source)
		portrait.tooltip_text = "Onboard AI" if RadioPortraits.identity(_portrait_source)==&"wick" else String(RadioPortraits.identity(_portrait_source)).capitalize()
	speaker.text = sources[selected]+" / RADIO"+(" · "+notice if not notice.is_empty() else "")
	if _playing!=selected:
		_playing = selected
		playback.start(texts[selected],not _reduced_motion)
		_remaining = playback.remaining()
		scroll.scroll_vertical = 0
	var typed: String = texts[selected].left(playback.characters())
	if preview.text!=typed:
		preview.text = typed
		if not expanded and not _reduced_motion: _follow_tail.call_deferred()
	preview.visible = not expanded
	transcript.visible = expanded
	scroll.visible = true
	scroll.focus_mode = Control.FOCUS_ALL if expanded else Control.FOCUS_NONE
	if transcript.text!=texts[selected]: transcript.text = texts[selected]
	actions.visible = expanded or selected=="dispatch"
	for button: Button in _buttons():
		button.focus_mode = Control.FOCUS_ALL if expanded else Control.FOCUS_NONE
		button.visible = expanded or button in [accept,later]
	accept.text = "Accept" if selected=="dispatch" else "Read"
	hint.text = _hint_text()
	for button: Button in _buttons():
		for property: String in ["focus_neighbor_left","focus_neighbor_right","focus_neighbor_top","focus_neighbor_bottom"]: button.set(property,NodePath("."))
## Says what each key does for the active device, so nothing about the radio has to be guessed.
func _hint_text() -> String:
	var context: InputContext = revision.scene.input_context
	var radio: String = context.describe(&"open_radio").get_slice(" / ",0)
	var back: String = "B" if context.controller else "Esc"
	if expanded:
		return "%s: close · %s: next · %s: scroll" % [back,"D-pad" if context.controller else "Tab","stick" if context.controller else "PgUp/PgDn"]
	if selected=="dispatch":
		return "%s: respond · %s: dismiss" % [radio,back]
	return "%s: open · %s: dismiss" % [radio,back]
func _buttons() -> Array[Button]:
	return _controls
func _focus_controls() -> Array[Control]:
	var controls: Array[Control] = []
	for button: Button in _controls:
		if button.visible: controls.append(button)
	controls.append(scroll)
	return controls
func _focus_action() -> void:
	var controls: Array[Control] = _focus_controls()
	controls[posmod(_choice,controls.size())].grab_focus()
func _comfort() -> void:
	_reduced_motion = revision.scene.settings.snapshot().accessibility.reduced_motion
	if _reduced_motion and playback.animated:
		playback.elapsed = maxf(0,playback.elapsed-playback.typing_seconds())
		playback.animated = false
func _follow_tail() -> void:
	if not expanded and panel.visible:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

func _input(event: InputEvent) -> void:
	if revision==null or not revision.scene.submarine.is_physics_processing() or revision.ui.modal(): return
	if expanded and scroll.has_focus() and (scroll as UiScrollReader).handle_reading_input(event):
		for action: StringName in InputBindings.ACTIONS:
			if event.is_action(action): Input.action_release(action)
		_consume_ui_event(event)
		return
	if event.is_echo(): return
	if not expanded and panel.visible and event.is_action_pressed("ui_cancel"):
		# Dismiss the preview without opening it; the message stays unread in the badge.
		collapse()
		_consume_ui_event(event)
		return
	if event.is_action_pressed("open_radio"):
		toggle()
		_consume_ui_event(event)
	elif expanded:
		if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
			_choice = _focus_controls().find(get_viewport().gui_get_focus_owner())+(-1 if event.is_action_pressed("ui_focus_prev") else 1)
			_focus_action()
			_consume_ui_event(event)
		elif event.is_action_pressed("ui_accept"):
			var focus: Control = get_viewport().gui_get_focus_owner()
			if focus is Button and is_ancestor_of(focus): (focus as Button).pressed.emit()
			_consume_ui_event(event)
		elif event.is_action_pressed("ui_cancel"):
			collapse()
			_consume_ui_event(event)
func _consume_ui_event(event: InputEvent) -> void:
	# Godot keeps just_pressed latched after action_release. Suppress only the
	# consumed sonar input step, preserving quick taps and ordinary ping commands.
	if event.is_action_pressed("sonar_ping"):
		_blocked_sonar_frame = Engine.get_physics_frames()+(0 if Engine.is_in_physics_frame() else 1)
	for action: StringName in [&"fire_torpedo",&"sonar_ping",&"interact"]:
		if event.is_action_pressed(action): Input.action_release(action)
	get_viewport().set_input_as_handled()

func sonar_input_allowed() -> bool:
	return Engine.get_physics_frames()>_blocked_sonar_frame

func _process(delta: float) -> void:
	if revision==null: return
	visible = revision.scene.submarine.is_physics_processing() and not revision.ui.modal()
	if not visible: return
	if not expanded:
		playback.advance(delta)
		_remaining = playback.remaining()
		if _remaining<=0: _next_preview()
	refresh()
	var viewport: Vector2 = get_viewport_rect().size
	var identity: Control = revision.scene.hud.identity_container()
	var bottom: float = minf(viewport.y-16,identity.position.y-8)
	var width: float = minf(360,viewport.x*0.48-16)
	badge.position = Vector2(16,bottom-36)
	badge.size = Vector2(width,32)
	var depth: Control = revision.scene.hud.get_node("%DepthPanel") as Control
	var deck: Control = revision.scene.hud.get_node("%InstrumentDeck") as Control
	var ceiling: float = maxf(depth.get_global_rect().end.y,deck.get_global_rect().end.y)+8
	var target_height: float = minf(360,bottom-44-ceiling)
	panel.size = Vector2(width,0)
	scroll.custom_minimum_size.y = 0
	var overhead: float = panel.get_combined_minimum_size().y
	scroll.custom_minimum_size.y = maxf(48,minf(96 if not expanded else 260,target_height-overhead))
	panel.size.y = scroll.custom_minimum_size.y+overhead
	panel.position = Vector2(16,bottom-44-panel.size.y)

func next_message() -> void:
	if pending.size()<2: return
	selected = pending[(pending.find(selected)+1)%pending.size()]
	notice = ""
	scroll.scroll_vertical = 0
	refresh()

func replay(id: String,body: String,source: String) -> void:
	enqueue(id,body,source)
	if not texts.has(id): return
	if id not in pending: pending.append(id)
	selected = id
	if not expanded: toggle()
	else: refresh()
