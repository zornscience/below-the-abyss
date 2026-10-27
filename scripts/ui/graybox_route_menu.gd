class_name GrayboxRouteMenu
extends Control
## Expedition pause/start UI plus distinctly labeled developer route restart.

signal save_requested
signal recover_requested
signal new_expedition_requested
signal resume_requested
signal story_requested
signal audio_requested
signal settings_requested
signal restart_requested


func _ready() -> void:
	(%Resume as Button).pressed.connect(func() -> void: resume_requested.emit())
	(%Settings as Button).pressed.connect(func() -> void: settings_requested.emit())
	(%OpenStory as Button).pressed.connect(func() -> void: story_requested.emit())
	(%AudioSettings as Button).pressed.connect(func() -> void: audio_requested.emit())
	(%Restart as Button).pressed.connect(func() -> void: restart_requested.emit())
	(%SaveExpedition as Button).pressed.connect(func() -> void: save_requested.emit())
	(%RecoverExpedition as Button).pressed.connect(func() -> void: recover_requested.emit())
	(%NewExpedition as Button).pressed.connect(show_new_confirmation)
	(%CancelNew as Button).pressed.connect(cancel_new)
	(%ConfirmNew as Button).pressed.connect(func() -> void:
		cancel_new()
		new_expedition_requested.emit())
	_wire_main_focus()
	for button: Button in [%CancelNew, %ConfirmNew]:
		var other: Button = %ConfirmNew if button == %CancelNew else %CancelNew
		for property: String in ["focus_next", "focus_previous", "focus_neighbor_left", "focus_neighbor_right", "focus_neighbor_top", "focus_neighbor_bottom"]:
			button.set(property, button.get_path_to(other))


func _wire_main_focus() -> void:
	var buttons: Array[Button] = []
	for button: Button in [%Resume, %Settings, %AudioSettings, %OpenStory, %Restart, %SaveExpedition, %NewExpedition, %RecoverExpedition]:
		if not button.disabled:
			buttons.append(button)
	for index: int in range(buttons.size()):
		for property: String in ["focus_previous", "focus_neighbor_left", "focus_neighbor_top"]:
			buttons[index].set(property, buttons[index].get_path_to(buttons[posmod(index - 1, buttons.size())]))
		for property: String in ["focus_next", "focus_neighbor_right", "focus_neighbor_bottom"]:
			buttons[index].set(property, buttons[index].get_path_to(buttons[(index + 1) % buttons.size()]))


func focus_resume() -> void:
	(%Resume as Button).grab_focus()


func configure_save_ui(available: bool, started: bool, enabled: bool, message: String) -> void:
	(%Resume as Button).text = "Continue saved expedition" if available and not started else "Begin / Resume test route"
	(%Resume as Button).disabled = not enabled and message != "Expedition saving not configured for this development fixture."
	(%SaveExpedition as Button).disabled = not enabled or (available and not started)
	(%NewExpedition as Button).disabled = not enabled
	(%RecoverExpedition as Button).disabled = not enabled and message == "Expedition saving not configured for this development fixture."
	(%ExpeditionSaveStatus as Label).text = message
	_wire_main_focus()


func show_new_confirmation() -> void:
	(%Help as Label).text = "Arrows / Tab / D-pad: choose · Enter / A: select · Esc / B / Start: cancel"
	(%NewConfirmation as Control).show()
	for control: Control in [%Brief, %Resume, %Settings, %Restart, %Tools, %SaveActions]:
		control.hide()
	(%CancelNew as Button).grab_focus()


func cancel_new() -> void:
	(%Help as Label).text = "Arrows / Tab / D-pad: navigate · Enter / A: select · Esc / B / Start: resume"
	(%NewConfirmation as Control).hide()
	for control: Control in [%Brief, %Resume, %Settings, %Restart, %Tools, %SaveActions]:
		control.show()
	focus_resume()


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and (%NewConfirmation as Control).visible and not event.is_echo() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		cancel_new()
