class_name GrayboxRouteMenu
extends Control
## Test-session controls. No station services or gameplay progression.

signal resume_requested
signal settings_requested
signal restart_requested


func _ready() -> void:
	var buttons: Array[Button] = [%Resume, %Settings, %Restart]
	(%Resume as Button).pressed.connect(func() -> void: resume_requested.emit())
	(%Settings as Button).pressed.connect(func() -> void: settings_requested.emit())
	(%Restart as Button).pressed.connect(func() -> void: restart_requested.emit())
	for index: int in range(buttons.size()):
		var previous: Button = buttons[posmod(index - 1, buttons.size())]
		var next: Button = buttons[(index + 1) % buttons.size()]
		for property: String in ["focus_previous", "focus_neighbor_left", "focus_neighbor_top"]:
			buttons[index].set(property, buttons[index].get_path_to(previous))
		for property: String in ["focus_next", "focus_neighbor_right", "focus_neighbor_bottom"]:
			buttons[index].set(property, buttons[index].get_path_to(next))


func focus_resume() -> void:
	(%Resume as Button).grab_focus()
