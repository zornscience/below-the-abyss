class_name CombatBox
extends Node2D
## Disposable composition. No campaign, research, mission, save or excavation service.
const DATA: CombatArenaProfile = preload("res://resources/playtesting/combat_arena.tres")
const SWARM: SwarmerProfile = preload("res://resources/playtesting/swarmer.tres")
const COSTS: ActionCostProfile = preload("res://resources/balance/twilight_action_costs.tres")
var submarine: SubmarineController
var torpedoes: TorpedoLauncher
var bus: AcousticBus
var effects: Node2D
var settings: SettingsStore = SettingsStore.new()
var input_context: InputContext
var hud: SubmarineHud
var audio: SoundscapeMixer
var observer: CombatBoxObserver
var stun: SonarStun
var swarmers: Array[CombatSwarmer] = []
var health: Array[BlastReceiver] = []
var stalker: RiftStalker
var bodies: Array[GrayboxRock] = []
var options: Control
var panel_title: Label
var profile_label: Label
var status: Label
var weighty_button: Button
var responsive_button: Button
var resume_button: Button
var refit_button: Button
var record_button: Button
var stop_button: Button
var profile_id: String = "weighty"
var _collision_latched: bool = false
var _collided_this_frame: bool = false
var _respawning: bool = false
func _ready() -> void:
	if not DATA.is_valid() or not SWARM.is_valid():
		push_error("Invalid combat test-box Resources")
		return
	var loaded: Error = settings.load_settings(SettingsStore.DEFAULT_PATH)
	if loaded not in [OK,ERR_FILE_NOT_FOUND]: push_warning("Combat box retained valid default preferences")
	var document: Dictionary = settings.snapshot()
	var calm: Dictionary = document.accessibility.duplicate(true)
	calm.reduced_flashing = true # Box-only, in memory; never saved over campaign preferences.
	settings.set_accessibility(calm)
	InputBindings.apply(document.bindings,document.deadzone)
	bus = AcousticBus.new()
	bus.name = "AcousticBus"
	add_child(bus)
	effects = Node2D.new()
	add_child(effects)
	_build_arena()
	submarine = preload("res://scenes/player/submarine.tscn").instantiate() as SubmarineController
	add_child(submarine)
	submarine.global_position = DATA.refit
	submarine.motion = CombatHandling.WEIGHTY
	(submarine.get_node("Visual") as Node2D).set("reduced_flashing",true)
	(submarine.get_node("Visual") as Node2D).set("reduced_motion",bool(document.accessibility.reduced_motion))
	submarine.resource_system.configure(preload("res://resources/balance/twilight_resources.tres"))
	_require(submarine.sonar.setup(bus,submarine.resource_system,effects))
	_require(submarine.sonar.set_battery_cost(COSTS.ping_battery))
	submarine.sonar.pulse_emitted.connect(_calm_ping)
	var camera: Camera2D = submarine.get_node("Camera2D") as Camera2D
	camera.limit_left = int(DATA.bounds.position.x)
	camera.limit_top = int(DATA.bounds.position.y)
	camera.limit_right = int(DATA.bounds.end.x)
	camera.limit_bottom = int(DATA.bounds.end.y)
	camera.reset_smoothing()
	audio = SoundscapeMixer.new()
	add_child(audio)
	audio.bind_settings(settings)
	torpedoes = TorpedoLauncher.new()
	add_child(torpedoes)
	_require(torpedoes.setup_ports(submarine,effects,bus,settings,audio.request))
	_require(torpedoes.set_battery_cost(COSTS.torpedo_battery))
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	hud = preload("res://scenes/ui/submarine_hud.tscn").instantiate() as SubmarineHud
	layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_require(hud.bind_sources(submarine.resource_system,submarine.hull_system,submarine.damage_system))
	hud.set_quiet_layout(true)
	observer = CombatBoxObserver.new()
	add_child(observer)
	observer.setup_box(submarine,torpedoes)
	_build_creatures()
	stun = SonarStun.new()
	add_child(stun)
	_require(stun.setup(submarine,swarmers))
	stun.used.connect(_stun_used)
	torpedoes.detonated.connect(_blast)
	submarine.hull_system.vessel_destroyed.connect(_destroyed)
	submarine.collision_occurred.connect(_collision)
	_build_options(layer)
	observer.status_changed.connect(_refresh_status)
	_refresh_status()
	for parent: Control in [hud,options]:
		for child: Node in parent.find_children("*","Control",true,false):
			UiTypography.apply(child as Control,String(document.accessibility.ui_scale))
	input_context = InputContext.new()
	add_child(input_context)
	input_context.setup(settings)
	input_context.controller_lost.connect(open_options)
	open_options()
func _require(result: Error) -> void:
	if result!=OK: push_error("Combat test-box setup: "+error_string(result))
func _build_arena() -> void:
	var water: Polygon2D = Polygon2D.new()
	water.polygon = SunlitSurveyData._rect(DATA.bounds)
	water.color = Color("092530")
	water.z_index = -10
	add_child(water)
	for outline: PackedVector2Array in DATA.polygons():
		var body: GrayboxRock = preload("res://scenes/props/graybox_rock.tscn").instantiate() as GrayboxRock
		body.outline = outline
		body.draw_outline = false
		add_child(body)
		bodies.append(body)
	var paint: SunlitRockDressing = SunlitRockDressing.new()
	add_child(paint)
	paint.configure_geometry(bodies,DATA.bounds)
	paint.set_active(true)
	var cradle: Sprite2D = Sprite2D.new()
	cradle.texture = preload("res://assets/art/sunlit/service_cradle.png")
	cradle.position = DATA.refit+Vector2(0,110)
	cradle.scale = Vector2.ONE*220.0/cradle.texture.get_width()
	add_child(cradle)
func _build_creatures() -> void:
	for index: int in range(DATA.swarm_spawns.size()):
		var instance: AcousticCreature = preload("res://scenes/creatures/acoustic_creature.tscn").instantiate() as AcousticCreature
		instance.set_script(preload("res://scripts/ai/combat_swarmer.gd"))
		var actor: CombatSwarmer = instance as CombatSwarmer
		actor.creature_id = StringName("testbox-swarmer-"+str(index))
		var profile: SwarmerProfile = SWARM.duplicate(true) as SwarmerProfile
		profile.patrol_points = PackedVector2Array([DATA.swarm_spawns[index]])
		actor.configuration = profile
		actor.position = DATA.swarm_spawns[index]
		actor.player = submarine
		add_child(actor)
		_require(actor.bind_bus(bus))
		actor.phase_changed.connect(_swarm_phase)
		actor.contact_damage_applied.connect(func(_amount: float) -> void: hud.show_threat_notice("! SWARMER / HULL CONTACT"))
		var receiver: BlastReceiver = BlastReceiver.new()
		receiver.maximum_health = profile.maximum_health
		actor.add_child(receiver)
		receiver.setup(actor)
		receiver.destroyed.connect(func() -> void:
			observer.observe("combat_engage","swarm")
			observer.observe("combat_outcome","swarm_destroyed")
			hud.show_threat_notice("SWARMER / DESTROYED"))
		torpedoes._receivers.append(receiver)
		health.append(receiver)
		swarmers.append(actor)
	var base: AcousticCreature = preload("res://scenes/creatures/acoustic_creature.tscn").instantiate() as AcousticCreature
	base.set_script(preload("res://scripts/ai/rift_stalker.gd"))
	stalker = base as RiftStalker
	stalker.configuration = DATA.stalker_profile()
	stalker.creature_id = &"testbox-rift-stalker"
	stalker.position = DATA.stalker_patrol[0]
	stalker.player = submarine
	add_child(stalker)
	_require(stalker.bind_bus(bus))
	stalker.collision_layer = 8
	stalker.phase_changed.connect(_stalker_phase)
	stalker.contact_damage_applied.connect(func(_amount: float) -> void: hud.show_threat_notice("! STALKER / HULL CONTACT"))
func _swarm_phase(phase: int) -> void:
	if phase in [SwarmerState.Phase.INVESTIGATE,SwarmerState.Phase.TELEGRAPH,SwarmerState.Phase.DASH]: observer.observe("combat_engage","swarm")
	if phase in [SwarmerState.Phase.TELEGRAPH,SwarmerState.Phase.DASH,SwarmerState.Phase.STUN]: hud.show_threat_notice("! SWARMER / "+SwarmerState.Phase.keys()[phase])
func _stalker_phase(phase: int) -> void:
	if phase in [RiftStalkerState.Phase.INVESTIGATE,RiftStalkerState.Phase.WARNING,RiftStalkerState.Phase.PURSUE,RiftStalkerState.Phase.STUN,RiftStalkerState.Phase.FLEE]: observer.observe("combat_engage","stalker")
	if phase in [RiftStalkerState.Phase.WARNING,RiftStalkerState.Phase.PURSUE,RiftStalkerState.Phase.STUN,RiftStalkerState.Phase.FLEE]: hud.show_threat_notice("! STALKER / "+RiftStalkerState.Phase.keys()[phase])
func _stun_used(affected: int) -> void:
	if affected<=0: return
	observer.observe("combat_engage","swarm")
	observer.observe("combat_stun","ping")
	observer.observe("combat_outcome","swarm_stunned",affected)
	hud.show_threat_notice("SONAR STUN / %d SWARMERS" % affected)
func _blast(_id: StringName,at: Vector2) -> void:
	if stalker.global_position.distance_to(at)<=stalker.hunt.profile.scare_radius:
		var result: Error = stalker.hunt.scare(at,stalker.position)
		if result==OK:
			observer.observe("combat_engage","stalker")
			observer.observe("combat_outcome","stalker_scared")
func _set_running(running: bool) -> void:
	observer._tick()
	observer._active = running
	submarine.set_simulation_enabled(running)
	for actor: CombatSwarmer in swarmers: actor.set_suspended(not running)
	stalker.set_suspended(not running)
	stalker.collision_layer = 8
func open_options() -> void:
	_set_running(false)
	options.show()
	profile_label.text = "HANDLING / "+profile_id.to_upper()
	refit_button.disabled = submarine.global_position.distance_to(DATA.refit)>DATA.refit_radius
	resume_button.grab_focus()
func resume() -> void:
	options.hide()
	_set_running(true)
func select_handling(id: String) -> Error:
	var motion: SubmarineMotion = CombatHandling.profile(id)
	if motion==null: return ERR_INVALID_PARAMETER
	profile_id = id
	submarine.motion = motion
	profile_label.text = "HANDLING / "+id.to_upper()
	observer.observe("combat_handling",id)
	return OK
func refit() -> Error:
	if submarine.global_position.distance_to(DATA.refit)>DATA.refit_radius: return ERR_UNAVAILABLE
	submarine.resource_system.restore_snapshot(submarine.resource_system.max_battery,submarine.resource_system.max_oxygen)
	submarine.hull_system.restore_snapshot(submarine.hull_system.max_hull)
	torpedoes.reset_session()
	torpedoes.refill()
	submarine.sonar.reset_session()
	for index: int in range(swarmers.size()):
		swarmers[index].reset_session()
		health[index].reset_session()
	stalker.reset_session()
	return OK
func _destroyed() -> void:
	if _respawning: return
	_respawning = true
	var source: String = String(submarine.hull_system.last_damage_source)
	observer.observe("combat_death","collision" if source=="collision" else ("swarm" if "swarmer" in source else ("stalker" if "stalker" in source else "other")))
	_set_running(false)
	_respawn.call_deferred()
func _respawn() -> void:
	submarine.global_position = DATA.refit
	submarine.velocity = Vector2.ZERO
	_require(refit())
	(submarine.get_node("Camera2D") as Camera2D).reset_smoothing()
	_respawning = false
	open_options()
	panel_title.text = "HULL LOST / Returned to arena refit"
func _collision(_normal: Vector2,_speed: float) -> void:
	_collided_this_frame = true
	if not _collision_latched:
		_collision_latched = true
		observer.observe("combat_collision","contact")
func _physics_process(_delta: float) -> void:
	if not _collided_this_frame: _collision_latched = false
	_collided_this_frame = false
func _process(_delta: float) -> void:
	if hud==null: return
	for id: String in ["OxygenGauge","DepthPanel","IdentityDetail","ConnectionStatus","SonarStatus","PassiveContacts","ThreatIndicator"]:
		var item: CanvasItem = hud.find_child(id,true,false) as CanvasItem
		if item!=null: item.hide()
	hud.identity_container().hide()
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and options!=null: open_options()
func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo(): return
	if event.is_action_pressed("pause") or InputBindings.is_menu_back(event):
		if options.visible: resume()
		else: open_options()
		get_viewport().set_input_as_handled()
	elif not options.visible and event.is_action_pressed("interact") and submarine.global_position.distance_to(DATA.refit)<=DATA.refit_radius:
		_require(refit())
		hud.show_threat_notice("ARENA REFIT / SUPPLIES RESTORED")
		get_viewport().set_input_as_handled()
func _build_options(layer: CanvasLayer) -> void:
	options = Control.new()
	options.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	options.theme = preload("res://resources/balance/instrument_theme.tres")
	layer.add_child(options)
	var background: ColorRect = ColorRect.new()
	background.color = Color("030b10")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	options.add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	options.add_child(margin)
	var scroll: UiScrollReader = UiScrollReader.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	panel_title = _label(content,"COMBAT TEST BOX / Developer options")
	_label(content,"Disposable arena. Quiet travel does not provoke hunters. Pings stun nearby swarmers, never the Stalker; torpedoes kill swarmers and scare the Stalker. Return to the visible cradle to refit (Interact). Pause opens this panel. Nothing here changes campaign progress.")
	profile_label = _label(content,"HANDLING / WEIGHTY")
	resume_button = _button(content,"Resume arena",resume)
	weighty_button = _button(content,"WEIGHTY / Campaign handling",_weighty)
	responsive_button = _button(content,"RESPONSIVE / Faster acceleration and reversal; longer coast",_responsive)
	refit_button = _button(content,"Refit / Reset wave at cradle",func() -> void: _require(refit()))
	_label(content,"LOCAL RECORDING: OFF each launch. Opt in to save anonymous relative times, combat counts, selected handling and a fixed-choice rating. No names, inputs, location, campaign state or uploads. Report files stay local; share only if you choose.")
	record_button = _button(content,"I agree / Start local combat recording",_record_start)
	stop_button = _button(content,"Disable recording / Export summary",func() -> void: observer.stop(); _refresh_status())
	_label(content,"After playing: how did the handling feel? Choosing a rating ends and exports this session.")
	for rating: String in ["weighty","about_right","sluggish","twitchy"]:
		var choice: String = rating
		_button(content,"Finish / "+choice.replace("_"," "),func() -> void: _rate(choice))
	_button(content,"Return to campaign title",_leave)
	status = _label(content,"Recording OFF. No human playtest results exist; every tuning number is a hypothesis.")
func _label(parent: Node,text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTypography.style(label,&"body")
	parent.add_child(label)
	return label
func _button(parent: Node,text: String,callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
func _weighty() -> void:
	_require(select_handling("weighty"))
func _responsive() -> void:
	_require(select_handling("responsive"))
func _record_start() -> void:
	var result: Error = observer.start()
	if result==OK: observer.observe("combat_handling",profile_id)
	_refresh_status()
func _rate(value: String) -> void:
	observer.observe("combat_rating",value)
	if observer.recorder.recording: observer.stop()
	_refresh_status()
func _refresh_status() -> void:
	status.text = ("Recording ON. " if observer.recorder.recording else "Recording OFF. ")+observer.status
	record_button.disabled = observer.recorder.recording
	stop_button.disabled = not observer.recorder.recording
func _leave() -> void:
	var result: Error = get_tree().change_scene_to_file("res://scenes/main/main.tscn")
	if result!=OK: status.text = "Title could not open: "+error_string(result)

func _calm_ping(event: AcousticEvent) -> void:
	var pulse: SonarPulse = submarine.sonar._pulses[event.event_id].get_ref() as SonarPulse
	if pulse!=null: pulse.reduced_flashing = true
