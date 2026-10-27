class_name PlaytestPanel
extends Control
signal close_requested
var observer: PlaytestObserver
var status_label: Label
var start_button: Button
var stop_button: Button
var export_button: Button
var close_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = preload("res://resources/balance/instrument_theme.tres")
	var background: ColorRect = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("030b10")
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
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
	_label(content, "PLAYTEST / Optional local reports", 24)
	var buttons: Array[Button] = []
	close_button = _button(content, "Return / Keep current recording choice", buttons, _close)
	_label(content, "Recording starts OFF each launch. If you choose to record, this game saves a random session ID, build version, gameplay/menu durations, counts of sonar, scans, discoveries, missions, station returns, warnings, hull damage and chapter progress. Only authored event labels and relative times are saved. No names, input recordings, device identifiers, precise location or unrelated files. Nothing is sent online.", 18)
	_label(content, "You can play without recording, disable it at any time, and decide whether to share the JSON/text report with your facilitator. Existing reports remain locally until you delete them. No recording before you opt in; chapter times cover this session only.", 18)
	start_button = _button(content, "I agree / Start local recording", buttons, func() -> void: observer.start(); _refresh())
	stop_button = _button(content, "Disable recording / Save summary", buttons, func() -> void: observer.stop(); _refresh())
	export_button = _button(content, "Export current JSON + readable summary", buttons, func() -> void: observer.export_report(); _refresh())
	_button(content, "Open local report folder", buttons, func() -> void:
		var result: Error = OS.shell_open(ProjectSettings.globalize_path(observer.store.directory))
		if result != OK:
			status_label.text = "Folder could not open. Location: " + ProjectSettings.globalize_path(observer.store.directory))
	_button(content, "Finish session and quit game", buttons, func() -> void: get_tree().quit())
	status_label = _label(content, "", 16)
	for index: int in range(buttons.size()):
		for property: String in ["focus_next", "focus_neighbor_bottom"]:
			buttons[index].set(property, buttons[index].get_path_to(buttons[(index + 1) % buttons.size()]))
		for property: String in ["focus_previous", "focus_neighbor_top"]:
			buttons[index].set(property, buttons[index].get_path_to(buttons[posmod(index - 1, buttons.size())]))
	hide()


func _label(parent: Node, text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, buttons: Array[Button], action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	buttons.append(button)
	return button


func present(value: PlaytestObserver) -> void:
	if observer == null:
		observer = value
		observer.status_changed.connect(_refresh)
	_refresh()
	show()
	close_button.grab_focus()


func _refresh() -> void:
	status_label.text = ("Recording ON. " if observer.recorder.recording else "Recording OFF. ") + observer.status
	start_button.disabled = observer.recorder.recording
	stop_button.disabled = not observer.recorder.recording
	export_button.disabled = observer.recorder.snapshot().is_empty()


func _close() -> void:
	hide()
	close_requested.emit()


func _input(event: InputEvent) -> void:
	if visible and not event.is_echo() and InputBindings.is_menu_back(event):
		get_viewport().set_input_as_handled()
		_close()
