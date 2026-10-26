class_name InputTestMenu
extends Control
## Input/settings demonstration only. No gameplay simulation or global singleton.

signal close_requested

@export var settings_path: String = SettingsStore.DEFAULT_PATH
@export var embedded: bool = false

var settings: SettingsStore = SettingsStore.new()
var capturing: bool = false
var _activations: int = 0
var _pause_indicator: bool = false

@onready var action_picker: OptionButton = %ActionPicker
@onready var rebind_button: Button = %Rebind
@onready var deadzone_slider: HSlider = %Deadzone
@onready var status: Label = %Status
@onready var bindings_label: Label = %Bindings


func _ready() -> void:
	for action: StringName in InputBindings.ACTIONS:
		action_picker.add_item(String(action).replace("_", " ").capitalize())
	action_picker.item_selected.connect(func(_index: int) -> void: _refresh_bindings())
	rebind_button.pressed.connect(_begin_remap)
	(%Activate as Button).pressed.connect(_activate)
	deadzone_slider.value_changed.connect(_change_deadzone)
	(%Save as Button).pressed.connect(_save)
	(%Reload as Button).pressed.connect(_reload)
	(%Reset as Button).pressed.connect(_reset)
	(%Quit as Button).pressed.connect(_exit_menu)
	if embedded:
		(%Quit as Button).text = "Return to movement (discard unsaved edits)"
	settings.settings_changed.connect(_apply_settings)
	var result: Error = settings.load_settings(settings_path)
	_apply_settings()
	if result == OK:
		status.text = "Loaded saved input settings."
	elif result == ERR_FILE_NOT_FOUND:
		status.text = "Using defaults. Save to keep changes between launches."
	else:
		status.text = "Settings could not be loaded (%s). Using defaults; saved file preserved." % error_string(result)
	var controls: Array[Control] = [
		%Activate, action_picker, rebind_button, deadzone_slider, %Save, %Reload, %Reset, %Quit,
	]
	for index: int in range(controls.size()):
		var previous: Control = controls[posmod(index - 1, controls.size())]
		var next: Control = controls[(index + 1) % controls.size()]
		controls[index].focus_neighbor_top = controls[index].get_path_to(previous)
		controls[index].focus_neighbor_bottom = controls[index].get_path_to(next)
		controls[index].focus_previous = controls[index].get_path_to(previous)
		controls[index].focus_next = controls[index].get_path_to(next)
	(%Activate as Button).grab_focus.call_deferred()


func _exit_menu() -> void:
	if embedded:
		close_requested.emit()
	else:
		get_tree().quit()


func _apply_settings() -> void:
	var document: Dictionary = settings.snapshot()
	InputBindings.apply(document["bindings"], float(document["deadzone"]))
	deadzone_slider.set_value_no_signal(float(document["deadzone"]))
	(%DeadzoneValue as Label).text = "Analog dead zone: %.2f" % float(document["deadzone"])
	_refresh_bindings()


func _refresh_bindings() -> void:
	var action: StringName = InputBindings.ACTIONS[action_picker.selected]
	bindings_label.text = InputBindings.describe(settings.snapshot()["bindings"], action)


func _activate() -> void:
	_activations += 1
	status.text = "Test activated %d time(s). No gameplay is implemented." % _activations


func _change_deadzone(value: float) -> void:
	settings.set_deadzone(value)
	status.text = "Dead zone changed. Save to persist."


func _save() -> void:
	var result: Error = settings.save_settings(settings_path)
	status.text = "Settings saved." if result == OK else "Save failed: %s. Changes remain in memory." % error_string(result)


func _reload() -> void:
	var result: Error = settings.load_settings(settings_path)
	status.text = "Settings reloaded." if result == OK else "Load failed: %s. Current settings retained." % error_string(result)


func _reset() -> void:
	settings.reset_defaults()
	status.text = "Defaults restored in memory. Save to persist."


func _begin_remap() -> void:
	capturing = true
	status.text = "Press a key/button or move a stick. Escape / controller B cancels."


func _input(event: InputEvent) -> void:
	if not capturing:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"):
		capturing = false
		status.text = "Remapping cancelled."
		return
	if event is InputEventKey and (not event.is_pressed() or event.is_echo()):
		return
	if event is InputEventJoypadButton and not event.is_pressed():
		return
	if InputBindings.from_event(event).is_empty():
		return
	var action: StringName = InputBindings.ACTIONS[action_picker.selected]
	var result: Error = settings.remap(action, event)
	if result == OK:
		capturing = false
		status.text = "Binding changed. Save to persist."
	else:
		status.text = "Binding rejected: unsupported or already used by another action. Try again or cancel."


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	if event.is_action_pressed("ui_cancel"):
		(%Activate as Button).grab_focus()
		status.text = "Returned focus to the first control."
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		_pause_indicator = not _pause_indicator
		status.text = "Pause input test: %s (no gameplay simulation)." % ("on" if _pause_indicator else "off")
		get_viewport().set_input_as_handled()
	else:
		for action: StringName in InputBindings.ACTIONS:
			if event.is_action_pressed(action):
				status.text = "%s input received. Gameplay is not implemented." % String(action).replace("_", " ").capitalize()
				break


func _process(_delta: float) -> void:
	var movement: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	(%Movement as Label).text = "Movement input only: X %.2f   Y %.2f" % [movement.x, movement.y]
