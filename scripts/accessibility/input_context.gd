class_name InputContext
extends Node
## Last deliberate input method; no glyph/device certification assumptions.
signal method_changed
signal controller_lost
var controller: bool = false
var active_device: int = -1
var settings: SettingsStore


func setup(value: SettingsStore) -> void:
	settings = value
	settings.settings_changed.connect(_changed)
	Input.joy_connection_changed.connect(connection_changed)


func _changed() -> void:
	method_changed.emit()


func observe(event: InputEvent) -> void:
	if event.is_echo():
		return
	var joy: bool = event is InputEventJoypadButton and event.is_pressed()
	joy = joy or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) >= 0.6)
	if joy:
		active_device = event.device
		if not controller:
			controller = true
			method_changed.emit()
	elif event is InputEventKey and event.is_pressed():
		if controller:
			controller = false
			method_changed.emit()


func _input(event: InputEvent) -> void:
	observe(event)


func describe(action: StringName) -> String:
	return InputBindings.describe_device(settings.snapshot().bindings, action, controller).replace("Controller ", "").replace("Back / Select", "Back").replace("Start / Menu", "Start") if settings != null else ""


func connection_changed(device: int, connected: bool) -> void:
	if connected or not controller or device != active_device:
		return
	for action: StringName in InputBindings.ACTIONS + InputBindings.MENU_ACTIONS:
		Input.action_release(action)
	controller = false
	active_device = -1
	method_changed.emit()
	controller_lost.emit()


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(connection_changed):
		Input.joy_connection_changed.disconnect(connection_changed)
	if settings != null and settings.settings_changed.is_connected(_changed):
		settings.settings_changed.disconnect(_changed)
