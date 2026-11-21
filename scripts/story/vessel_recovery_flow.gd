class_name VesselRecoveryFlow
extends CanvasLayer
## Campaign failure: hull destruction or life-support expiry leads to Halcyon recovery in
## both chapters (Sunlit and Twilight). Replaces the BTA-059 ascent-tether respawn.
## Session-only: the countdown and this presentation write no new save fields.

signal recovery_started(cause: StringName)
signal recovery_completed

const PROFILE: VesselRecoveryProfile = preload("res://resources/balance/vessel_recovery.tres")
const FADE_SECONDS: float = 0.5
## Accept input is ignored until the fade has finished plus this long, so a press meant
## for piloting or a held button cannot dismiss the card before it can be read.
const ACCEPT_DELAY_SECONDS: float = 0.5
const FOOTER_TEXT: String = "Enter / A: continue"
const CAUSE_OXYGEN: StringName = &"oxygen"
const SHARED_TEXT: String = "Wick sent a distress beacon and Halcyon’s crew recovered Lantern-2. Hull, battery, oxygen and torpedoes are restored. The unfinished scan was cancelled. All records, discoveries and choices are kept."
const OXYGEN_TEXT: String = "LIFE SUPPORT FAILED. Oxygen ran out. " + SHARED_TEXT
const CONFIRM_TEXT: String = "Continue at Halcyon"
const RETRY_TEXT: String = "Recovery could not be saved. Press Enter or A to retry."

var scene: ShelfPrototype
var countdown: LifeSupportCountdown = LifeSupportCountdown.new()
var warning: LifeSupportWarning
var pending: bool = false
var committed: bool = false
var cause: StringName = &""
var backdrop: ColorRect
var panel: PanelContainer
var body: Label
var confirm: Button
var footer: Label
var alarms_requested: int = 0
var _fade: float = 0.0
var _shown_seconds: float = 0.0
var _card_text: String = ""


func setup(game: ShelfPrototype) -> void:
	scene = game
	layer = 110
	if countdown.configure(PROFILE) != OK:
		push_error("Invalid vessel recovery profile. Fix resources/balance/vessel_recovery.tres.")
	var warning_layer: CanvasLayer = CanvasLayer.new()
	warning_layer.name = "LifeSupportLayer"
	warning_layer.layer = 45
	add_child(warning_layer)
	warning = LifeSupportWarning.new()
	warning.anchor = scene.hud.oxygen_gauge
	warning_layer.add_child(warning)
	backdrop = ColorRect.new()
	backdrop.name = "RecoveryFade"
	backdrop.color = Color(0, 0, 0, 0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.hide()
	panel = PanelContainer.new()
	panel.name = "RecoveryCard"
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.theme = preload("res://resources/balance/instrument_theme.tres")
	panel.size = Vector2(540, 280)
	var column: VBoxContainer = VBoxContainer.new()
	panel.add_child(column)
	body = Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size = Vector2(500, 0)
	column.add_child(body)
	UiTypography.style(body, &"body")
	confirm = Button.new()
	confirm.name = "ContinueAtHalcyon"
	confirm.text = CONFIRM_TEXT
	column.add_child(confirm)
	confirm.pressed.connect(acknowledge)
	footer = Label.new()
	footer.text = FOOTER_TEXT
	footer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(footer)
	UiTypography.style(footer, &"body")
	panel.hide()
	countdown.started.connect(_countdown_started)
	countdown.critical.connect(func(_left: float) -> void: _alarm())
	countdown.cancelled.connect(warning.dismiss)
	countdown.expired.connect(func() -> void: trigger(CAUSE_OXYGEN))
	scene.submarine.hull_system.vessel_destroyed.connect(_destroyed)
	scene.saves.checkpoint_restored.connect(_restored)
	# Freeze the pulse the moment the simulation pauses, not on the next physics step.
	scene.submarine.simulation_enabled_changed.connect(func(enabled: bool) -> void: warning.animating = enabled)


## True once the card has faded in and the accept delay has passed.
func accept_ready() -> bool:
	return pending and _shown_seconds >= FADE_SECONDS + ACCEPT_DELAY_SECONDS


## Sunlit chapter, the Twilight expedition or the Drowned Caves. Legacy prototype modes keep no failure flow.
func campaign_active() -> bool:
	if scene == null or scene.journey == null:
		return false
	return scene.journey.in_field() or (scene.chapter != null and scene.chapter.active)


func _physics_process(delta: float) -> void:
	if pending or not campaign_active():
		if warning.visible and not pending:
			warning.dismiss()
		return
	var running: bool = scene.submarine.is_physics_processing()
	warning.animating = running
	# Simulation time only: menus, map, dialogs and pause freeze the countdown.
	var oxygen: float = scene.submarine.resource_system.oxygen
	if running:
		countdown.advance(delta, oxygen)
	elif countdown.running and oxygen > 0.0:
		# Refilled while paused (Halcyon dock service): cancel now, no time passes.
		countdown.advance(0.0, oxygen)
	if countdown.running:
		warning.present(countdown.remaining, countdown.grace_seconds)


func _countdown_started(grace: float) -> void:
	warning.present(grace, grace)
	_alarm()


## Reuses the existing oxygen alarm cue (no new audio). The border and text are the
## visible equivalent at the same moments: depletion and the critical threshold.
func _alarm() -> void:
	alarms_requested += 1
	if scene.gameplay_audio != null:
		scene.gameplay_audio.life_support_alarm()


func _destroyed() -> void:
	if campaign_active():
		trigger.call_deferred(scene.submarine.hull_system.last_damage_source)


func _restored() -> void:
	# Continue never resumes a countdown mid-way: oxygen at zero restarts the full grace.
	if pending:
		return
	countdown.reset_session()
	warning.dismiss()
	if campaign_active() and scene.submarine.hull_system.hull <= 0.0:
		# A hull-failure checkpoint written by the BTA-059 flow is recovered on Continue.
		trigger.call_deferred(&"restored")


func card_text(failure: StringName) -> String:
	if failure == CAUSE_OXYGEN:
		return OXYGEN_TEXT
	var reason: String = "Hull integrity was depleted."
	if failure == &"pressure" or scene.submarine.damage_system.depth_m > scene.submarine.damage_system.get_maximum_depth_m():
		reason = "Pressure exceeded the hull rating."
	if failure == &"collision":
		reason = "A collision depleted hull integrity."
	if String(failure).begins_with("thermal/"):
		reason = "Thermal vent exposure depleted hull integrity."
	return "HULL FAILURE. " + reason + " " + SHARED_TEXT


func trigger(failure: StringName) -> void:
	if pending or not campaign_active():
		return
	pending = true
	committed = false
	cause = failure
	countdown.reset_session()
	warning.dismiss()
	scene.submarine.set_simulation_enabled(false)
	scene.submarine.velocity = Vector2.ZERO
	scene.submarine.scanner.cancel_scan()
	scene.revision.ui.notifications.collapse()
	var kind: StringName = &"oxygen" if failure == CAUSE_OXYGEN else &"hull"
	# Playtest telemetry: the failure event is this real recovery trigger, nothing earlier.
	if scene.playtest_observer != null:
		scene.playtest_observer.record_failure(kind)
	recovery_started.emit(kind)
	_card_text = card_text(failure)
	body.text = _card_text
	_fade = 0.0
	_shown_seconds = 0.0
	backdrop.color = Color(0, 0, 0, 0)
	backdrop.show()
	_center()
	panel.show()
	confirm.grab_focus()
	_commit()


func _commit() -> void:
	# A casualty record that failed to save blocks every other checkpoint. Retry it first.
	if scene.journey.expedition != null:
		scene.journey.expedition.retry_casualty_record()
	var result: Error = scene.saves.recover_vessel()
	committed = result == OK
	scene.submarine.set_simulation_enabled(false)
	if committed:
		# A successful retry clears the retry line.
		body.text = _card_text
	elif not body.text.ends_with(RETRY_TEXT):
		body.text += "\n" + RETRY_TEXT


func acknowledge() -> void:
	if not pending:
		return
	if not committed:
		_commit()
		return
	pending = false
	panel.hide()
	backdrop.hide()
	countdown.reset_session()
	if scene.journey.at_station():
		scene.journey.show_station()
	else:
		scene.resume_route()
	recovery_completed.emit()


func _center() -> void:
	panel.reset_size()
	panel.position = (get_viewport().get_visible_rect().size - panel.size) * 0.5


func _input(event: InputEvent) -> void:
	if not pending:
		return
	if event is InputEventMouse:
		return
	# Echoes come from a held key. A fresh press is required once the card is ready.
	if event.is_action_pressed("ui_accept") and not event.is_echo() and accept_ready():
		acknowledge()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not pending:
		return
	_shown_seconds += delta
	_fade = minf(1.0, _fade + delta / FADE_SECONDS)
	backdrop.color = Color(0, 0, 0, _fade)
	_center()
	scene.submarine.set_simulation_enabled(false)
