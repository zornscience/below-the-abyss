class_name InputBindings
extends RefCounted
## Serializable bindings for gameplay actions; menu navigation is a fixed fallback.

const ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down",
	&"interact", &"sonar_ping", &"pause", &"toggle_lights", &"open_map", &"fire_torpedo",
]
const MENU_ACTIONS: Array[StringName] = [
	&"ui_left", &"ui_right", &"ui_up", &"ui_down",
	&"ui_accept", &"ui_cancel", &"ui_focus_next", &"ui_focus_prev",
]


static func defaults() -> Dictionary:
	var result: Dictionary = {}
	for action: StringName in ACTIONS:
		var descriptors: Array[Dictionary] = []
		var definition: Dictionary = ProjectSettings.get_setting("input/" + String(action), {})
		for event: InputEvent in definition.get("events", []):
			descriptors.append(from_event(event))
		result[String(action)] = descriptors
	return result


static func is_integer(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) \
		and is_finite(float(value)) and float(value) == floorf(float(value))


static func valid_descriptor(binding: Dictionary) -> bool:
	match binding.get("kind"):
		"key":
			if binding.size() != 2 or not is_integer(binding.get("code")):
				return false
			var code: int = int(binding["code"])
			if code in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
				return false
			return (code >= KEY_SPACE and code <= KEY_ASCIITILDE) \
				or (code >= KEY_ESCAPE and code <= KEY_F35)
		"button":
			return binding.size() == 2 and is_integer(binding.get("code")) \
				and float(binding["code"]) >= 0 and float(binding["code"]) < JOY_BUTTON_MAX
		"axis":
			return binding.size() == 3 and is_integer(binding.get("axis")) \
				and float(binding["axis"]) >= 0 and float(binding["axis"]) < JOY_AXIS_MAX \
				and is_integer(binding.get("direction")) and absf(float(binding["direction"])) == 1.0
	return false


static func binding_id(binding: Dictionary) -> String:
	if binding["kind"] == "axis":
		return "axis:%d:%d" % [int(binding["axis"]), int(binding["direction"])]
	return "%s:%d" % [binding["kind"], int(binding["code"])]


static func valid_bindings(bindings: Variant, actions: Array[StringName] = ACTIONS) -> bool:
	if not bindings is Dictionary or bindings.size() != actions.size():
		return false
	var seen: Dictionary = {}
	for action: StringName in actions:
		var entries: Variant = bindings.get(String(action))
		if not entries is Array or entries.is_empty() or entries.size() > 8:
			return false
		var has_key: bool = false
		var has_controller: bool = false
		for entry: Variant in entries:
			if not entry is Dictionary or not valid_descriptor(entry):
				return false
			var identifier: String = binding_id(entry)
			if seen.has(identifier):
				return false
			seen[identifier] = true
			has_key = has_key or entry["kind"] == "key"
			has_controller = has_controller or entry["kind"] != "key"
		if not has_key or not has_controller:
			return false
	return true


static func from_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.alt_pressed or key.ctrl_pressed or key.meta_pressed or key.shift_pressed:
			return {}
		var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
		if code in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			return {}
		return {"kind": "key", "code": code}
	if event is InputEventJoypadButton:
		return {"kind": "button", "code": (event as InputEventJoypadButton).button_index}
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		if absf(motion.axis_value) >= 0.6:
			return {"kind": "axis", "axis": motion.axis, "direction": -1 if motion.axis_value < 0 else 1}
	return {}


static func to_event(binding: Dictionary) -> InputEvent:
	if binding["kind"] == "key":
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = int(binding["code"])
		return key
	if binding["kind"] == "button":
		var button: InputEventJoypadButton = InputEventJoypadButton.new()
		button.device = -1
		button.button_index = int(binding["code"])
		return button
	var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion.device = -1
	motion.axis = int(binding["axis"])
	motion.axis_value = float(binding["direction"])
	return motion


static func normalized(bindings: Dictionary) -> Dictionary:
	# JSON numbers are floats. Rebuild descriptors to keep integer enum codes
	# consistent with editor defaults and descriptors captured from live events.
	var result: Dictionary = {}
	for action: StringName in ACTIONS:
		var entries: Array[Dictionary] = []
		for binding: Dictionary in bindings[String(action)]:
			entries.append(from_event(to_event(binding)))
		result[String(action)] = entries
	return result


static func apply(bindings: Dictionary, deadzone: float) -> Error:
	if not valid_bindings(bindings) or not is_finite(deadzone) or deadzone < 0.1 or deadzone > 0.9:
		return ERR_INVALID_PARAMETER
	for action: StringName in ACTIONS + MENU_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		Input.action_release(action)
		InputMap.action_erase_events(action)
		InputMap.action_set_deadzone(action, deadzone)
		if action in ACTIONS:
			for descriptor: Dictionary in bindings[String(action)]:
				InputMap.action_add_event(action, to_event(descriptor))
		else:
			var definition: Dictionary = ProjectSettings.get_setting("input/" + String(action), {})
			for event: InputEvent in definition.get("events", []):
				InputMap.action_add_event(action, event)
	return OK


static func describe(bindings: Dictionary, action: StringName) -> String:
	var names: PackedStringArray = []
	for descriptor: Dictionary in bindings[String(action)]:
		if descriptor["kind"] == "key":
			names.append(OS.get_keycode_string(int(descriptor["code"])))
		elif descriptor["kind"] == "button":
			var labels: Dictionary = {
				JOY_BUTTON_A: "Controller A", JOY_BUTTON_B: "Controller B",
				JOY_BUTTON_X: "Controller X", JOY_BUTTON_Y: "Controller Y",
				JOY_BUTTON_BACK: "Back / Select", JOY_BUTTON_START: "Start / Menu",
				JOY_BUTTON_LEFT_STICK: "Left stick click", JOY_BUTTON_RIGHT_STICK: "Right stick click",
				JOY_BUTTON_LEFT_SHOULDER: "Left shoulder", JOY_BUTTON_RIGHT_SHOULDER: "Right shoulder",
				JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
				JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
			}
			names.append(labels.get(int(descriptor["code"]), "Controller button %d" % int(descriptor["code"])))
		else:
			var axis: int = int(descriptor["axis"])
			var negative: bool = int(descriptor["direction"]) < 0
			match axis:
				JOY_AXIS_LEFT_X:
					names.append("Left stick left" if negative else "Left stick right")
				JOY_AXIS_LEFT_Y:
					names.append("Left stick up" if negative else "Left stick down")
				JOY_AXIS_RIGHT_X:
					names.append("Right stick left" if negative else "Right stick right")
				JOY_AXIS_TRIGGER_RIGHT:
					names.append("Right trigger")
				JOY_AXIS_TRIGGER_LEFT:
					names.append("Left trigger")
				JOY_AXIS_RIGHT_Y:
					names.append("Right stick up" if negative else "Right stick down")
				_:
					names.append("Controller axis %d (%s)" % [axis, "-" if negative else "+"])
	return " / ".join(names)


static func is_menu_navigation(event: InputEvent) -> bool:
	for action: StringName in MENU_ACTIONS:
		if action != &"ui_cancel" and event.is_action_pressed(action):
			return true
	return false


static func is_menu_back(event: InputEvent) -> bool:
	# Fixed recovery controls take priority over a gameplay remap like Pause=Enter.
	return event.is_action_pressed("ui_cancel") or (event.is_action_pressed("pause") and not is_menu_navigation(event))


static func describe_device(bindings: Dictionary, action: StringName, controller: bool) -> String:
	var filtered: Dictionary = bindings.duplicate(true)
	var entries: Array[Dictionary] = []
	for entry: Dictionary in bindings[String(action)]:
		if (entry.kind != "key") == controller:
			entries.append(entry)
	filtered[String(action)] = entries
	return describe(filtered, action)


static func compatible_bindings(value: Variant) -> Dictionary:
	if valid_bindings(value):
		return value.duplicate(true)
	var legacy: Array[StringName] = ACTIONS.duplicate()
	legacy.erase(&"fire_torpedo")
	if not valid_bindings(value, legacy):
		return {}
	var result: Dictionary = value.duplicate(true)
	var used: Dictionary = {}
	for action: String in result:
		for entry: Dictionary in result[action]:
			used[binding_id(entry)] = true
	var chosen: Array[Dictionary] = []
	for code: int in [KEY_SPACE, KEY_R, KEY_G, KEY_V, KEY_T] + range(KEY_F1, KEY_F35+1):
		var entry: Dictionary = {"kind":"key","code":code}
		if not used.has(binding_id(entry)):
			chosen.append(entry)
			break
	for entry: Dictionary in [{"kind":"axis","axis":JOY_AXIS_TRIGGER_RIGHT,"direction":1}, {"kind":"button","code":JOY_BUTTON_RIGHT_SHOULDER}, {"kind":"axis","axis":JOY_AXIS_TRIGGER_LEFT,"direction":1}, {"kind":"button","code":JOY_BUTTON_LEFT_SHOULDER}, {"kind":"button","code":JOY_BUTTON_RIGHT_STICK}]:
		if not used.has(binding_id(entry)):
			chosen.append(entry)
			break
	result["fire_torpedo"] = chosen
	return result if valid_bindings(result) else {}
