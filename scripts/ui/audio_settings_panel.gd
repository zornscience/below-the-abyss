class_name AudioSettingsPanel
extends Control
## Live preview; explicit Save commits the existing settings file. Cancel restores.

signal close_requested
var settings: SettingsStore
var mixer: SoundscapeMixer
var settings_path: String
var _original: Dictionary
var _draft: Dictionary
var sliders: Dictionary[String, HSlider] = {}
var volume_labels: Dictionary[String, Label] = {}
var mute_button: CheckButton
var status: Label
var save_button: Button
var cancel_button: Button
var _controls: Array[Control] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = preload("res://resources/balance/instrument_theme.tres")
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.015, 0.035, 0.05, 1.0)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	_label(content, "AUDIO / Underwater soundscape", 24)
	_label(content, "↑↓ / Tab / D-pad: choose · ←→: volume · Enter / A: select · Escape / B: discard", 16)
	for bus: String in SoundscapeMixer.BUSES:
		var label: Label = _label(content, bus + " / 0%", 18)
		var slider: HSlider = HSlider.new()
		slider.name = bus
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size.y = 32.0
		content.add_child(slider)
		sliders[bus] = slider
		volume_labels[bus] = label
		slider.focus_entered.connect(_refresh_volume_label.bind(bus))
		slider.focus_exited.connect(_refresh_volume_label.bind(bus))
		_controls.append(slider)
		slider.value_changed.connect(func(value: float) -> void:
			_refresh_volume_label(bus)
			_draft[bus] = value
			mixer.apply_audio(_draft))
	mute_button = CheckButton.new()
	mute_button.text = "Mute all sound (visual instruments remain available)"
	content.add_child(mute_button)
	_controls.append(mute_button)
	mute_button.toggled.connect(func(value: bool) -> void:
		_draft.muted = value
		mixer.apply_audio(_draft))
	save_button = Button.new()
	save_button.text = "Save audio settings"
	content.add_child(save_button)
	_controls.append(save_button)
	save_button.pressed.connect(_save)
	cancel_button = Button.new()
	cancel_button.text = "Return / discard unsaved audio edits"
	content.add_child(cancel_button)
	_controls.append(cancel_button)
	cancel_button.pressed.connect(cancel)
	status = _label(content, "Preview changes here. Music is intentionally silent in this region.", 16)
	for index: int in range(_controls.size()):
		for property: String in ["focus_next", "focus_neighbor_bottom"]:
			_controls[index].set(property, _controls[index].get_path_to(_controls[(index + 1) % _controls.size()]))
		for property: String in ["focus_previous", "focus_neighbor_top"]:
			_controls[index].set(property, _controls[index].get_path_to(_controls[posmod(index - 1, _controls.size())]))
	hide()


func _refresh_volume_label(bus: String) -> void:
	var focused: bool = sliders[bus].has_focus()
	volume_labels[bus].text = "%s%s / %.0f%%" % ["▶ " if focused else "", bus, sliders[bus].value * 100.0]
	volume_labels[bus].modulate = Color("d9e0a6") if focused else Color.WHITE


func _label(parent: Node, text: String, size_px: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size_px)
	parent.add_child(label)
	return label


func present(store: SettingsStore, audio: SoundscapeMixer, path: String) -> void:
	settings = store
	mixer = audio
	settings_path = path
	status.text = "Preview changes here. Music is intentionally silent in this region."
	_original = store.snapshot().audio
	_draft = _original.duplicate(true)
	for bus: String in sliders:
		sliders[bus].value = float(_draft[bus])
	mute_button.set_pressed_no_signal(bool(_draft.muted))
	show()
	sliders.Master.grab_focus()


func _save() -> void:
	settings.set_audio(_draft)
	var result: Error = settings.save_settings(settings_path)
	if result == OK:
		_original = _draft.duplicate(true)
		status.text = "Audio settings saved. Return to continue."
	else:
		settings.set_audio(_original)
		mixer.apply_audio(_draft)
		status.text = "Save failed (%s). Saved file preserved; preview remains unsaved." % error_string(result)


func cancel() -> void:
	mixer.apply_audio(_original)
	hide()
	close_requested.emit()


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and not event.is_echo() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		cancel()
