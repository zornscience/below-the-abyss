class_name TwilightDepthGate
extends CanvasLayer
## Transient failure presentation derived from hull state. No new save fields.
var scene: ShelfPrototype
var pending: bool = false
var panel: PanelContainer
var body: Label
var confirm: Button
var footer: Label
var _hint_attempted: bool = false
var _near: bool = false
var _depth_cache: float = -1.0
var _rating_cache: float = -1.0
func setup(game: ShelfPrototype) -> void:
	scene = game
	layer = 110
	panel = PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.theme = preload("res://resources/balance/instrument_theme.tres")
	panel.position = Vector2.ZERO
	panel.size = Vector2(540,280)
	var column: VBoxContainer = VBoxContainer.new()
	panel.add_child(column)
	body = Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	UiTypography.style(body,&"body")
	confirm = Button.new()
	confirm.text = "Respawn at ascent tether"
	column.add_child(confirm)
	confirm.pressed.connect(respawn)
	footer = Label.new()
	footer.text = "Enter / A: respawn   ·   Esc / B: stay on this panel"
	footer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(footer)
	UiTypography.style(footer,&"body")
	panel.hide()
	scene.submarine.hull_system.vessel_destroyed.connect(_destroyed)
	scene.saves.checkpoint_restored.connect(_restored)
	scene.settings.settings_changed.connect(func() -> void: _hint_attempted = false)
func _destroyed() -> void:
	if scene.journey.active(): show_failure.call_deferred()
func _restored() -> void:
	if scene.journey.active() and scene.submarine.hull_system.hull<=0: show_failure.call_deferred()
func show_failure() -> void:
	if pending or not scene.journey.active(): return
	pending = true
	scene.submarine.set_simulation_enabled(false)
	scene.submarine.velocity = Vector2.ZERO
	scene.submarine.scanner.cancel_scan()
	scene.revision.ui.notifications.collapse()
	var cause: String = "Pressure exceeded the hull rating" if scene.submarine.hull_system.last_damage_source==&"pressure" or scene.submarine.damage_system.depth_m>scene.submarine.damage_system.get_maximum_depth_m() else "Hull integrity was depleted"
	if scene.submarine.hull_system.last_damage_source==&"collision": cause = "A collision depleted hull integrity"
	if String(scene.submarine.hull_system.last_damage_source).begins_with("thermal/"): cause = "Thermal vent exposure depleted hull integrity"
	body.text = cause+".\n\nRespawn restores hull at the ascent tether. Battery and oxygen stay as they are. The unfinished scan is cancelled. All permanent records and choices are retained."
	var result: Error = scene.saves._write(scene.saves.snapshot(),"Hull failure recorded.")
	if result!=OK: body.text += "\nCheckpoint failed; retry respawn before quitting."
	panel.position = (get_viewport().get_visible_rect().size-panel.size)*0.5
	panel.show()
	confirm.grab_focus()
func respawn() -> void:
	if not pending: return
	var candidate: Dictionary = scene.saves.snapshot()
	candidate.player.hull = scene.submarine.hull_system.max_hull
	candidate.player.position = [TwilightShelfLayout.SPAWN.x,TwilightShelfLayout.SPAWN.y]
	candidate.player.rotation = 0.0
	var result: Error = scene.saves._write(candidate,"Respawn saved; permanent progress retained.")
	if result!=OK:
		body.text += "\nRespawn could not be saved. Confirm to retry."
		return
	pending = false
	panel.hide()
	if scene.saves.continue_expedition()!=OK:
		pending = true
		panel.show()
		return
	scene.resume_route()
func _input(event: InputEvent) -> void:
	if not pending: return
	if event is InputEventMouse: return
	if event.is_action_pressed("ui_accept"):
		respawn()
	get_viewport().set_input_as_handled()
func _process(_delta: float) -> void:
	if scene==null or not scene.journey.active(): return
	if pending:
		panel.position = (get_viewport().get_visible_rect().size-panel.size)*0.5
		scene.submarine.set_simulation_enabled(false)
		return
	var gate: DepthGateProfile = TwilightShelfLayout.DEPTH_GATE
	var near: bool = scene.submarine.global_position.distance_to(gate.approach)<600 or scene.submarine.global_position.distance_to(gate.exit)<600
	var damage: SubmarineDamageSystem = scene.submarine.damage_system
	if near!=_near or damage.depth_m!=_depth_cache or damage.get_maximum_depth_m()!=_rating_cache:
		_near = near
		_depth_cache = damage.depth_m
		_rating_cache = damage.get_maximum_depth_m()
		scene.hud._depth_changed(_depth_cache,_rating_cache)
		if near: (scene.hud.get_node("%DepthValue") as Label).text = "%.0f m / BASIN %.0f m" % [_depth_cache,gate.depth_m]
	if near and not _hint_attempted and scene.submarine.is_physics_processing() and scene.tutorial._current=="":
		_hint_attempted = true
		scene.tutorial.show_hint("twilight-depth")
