class_name ExpeditionRevision
extends Node
## Scene-owned adapter: existing mission/scan/discovery events feed radio and research talents.
signal logs_decoded
signal research_changed
const TREE: ResearchTree = preload("res://resources/campaign/research_tree.tres")
const WRECK: StringName = &"lost-expedition-blackbox"
const TRANSMISSIONS: Dictionary = {
	"survey-complete":"Outer-shelf survey complete. +1 RESEARCH POINT awarded. Your hydrophone and chimney-field studies are archived. Assign the point or reassign your existing talents at Shelf Base; the expedition has a finite research budget.",
	"dispatch":"We lost contact with one of our expeditions. Can you investigate? We are marking their last reported position at Twin Spires on your map. Scan the reference plate just east of base for their survey notes, then follow the recovered evidence. Accepting this transmission activates the investigation; no station board is required.",
	"relay":"Your survey points beyond Twin Spires. Follow the outer shelf to the abandoned hydrophone, then study the mineral chimneys. The receiver record should carry their next heading. A research point is awarded when this outer survey is complete.",
	"wreck-recovered":"Encrypted expedition logs received aboard NERIS. Return to Shelf Base: our decoding equipment can recover the damaged recordings. Keep the recorder safe; its research record survives saving and reloading.",
	"next-signal":"The decoded logs contain a bearing into the Twilight Reef. The missing crew left their vessel before the final transmission. We have opened the next investigation dossier. The next region is not yet playable; you can continue researching the shelf and reassign your research points at base."}
var scene: ShelfPrototype
var tree: ResearchTree
var ui: ExpeditionInterface
var campaign: Dictionary = CampaignData.fresh()
var feedback: String = ""
var docking_report: String = ""
var returning_to_title: bool = false
var _clock: float = 0.0
var _defer_until: float = 0.0
var _radio_id: String = ""
var _ammo_label: Label
var scavenger: WreckScavenger
func setup(owner_scene: ShelfPrototype) -> void:
	scene = owner_scene
	tree = TREE.duplicate(true) as ResearchTree
	assert(tree.is_valid())
	if scene.saves!=null: campaign = CampaignData.normalized(scene.saves._state.prototype.campaign)
	scene.upgrades.installation_guard = func() -> bool: return false
	scene.upgrades.capability_override = capabilities
	scene.upgrades.reapply()
	scene.submarine.motion = preload("res://resources/balance/expedition_motion.tres").duplicate(true) as SubmarineMotion
	scene.narrative.radio_assignments = true
	scene.narrative.debrief_guard = func() -> bool: return bool(campaign.decoded)
	scene.research_log.entry_text_provider = research_text
	ui = ExpeditionInterface.new()
	add_child(ui)
	ui.setup(self)
	_ammo_label = Label.new()
	_ammo_label.add_theme_font_size_override("font_size",18)
	_ammo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scene.hud.get_node("Top/Identity").add_child(_ammo_label)
	scene.torpedoes.ammunition_changed.connect(func(_current: int,_maximum: int) -> void: _refresh_ammo())
	if scene.saves!=null: scene.torpedoes.restore_ammunition(int(scene.saves._state.prototype.ammunition))
	scene.missions.missions_changed.connect(_reward_survey_deferred)
	scene.research.scan_completed.connect(func(_id: StringName) -> void: _reward_survey_deferred())
	# Radio offers replace the board and manual mission acceptance in the old log.
	scene.expedition_log.begin_button.hide()
	scene.expedition_log.begin_button.disabled = true
	scene.expedition_log.visibility_changed.connect(func() -> void:
		scene.expedition_log.begin_button.hide()
		scene.expedition_log.begin_button.disabled = true)
	scene.route_layer.hide()
	_reward_survey.call_deferred()
	_setup_world()
	_refresh_ammo()
	scene.accessibility_service.queue_apply()
func can_write() -> bool:
	return scene.saves!=null and scene.saves.can_write()
func capabilities() -> Dictionary:
	return {"sonar":tree.sonar_radii[int(campaign.ranks.sonar)],"hull":tree.hull_ratings[int(campaign.ranks.hull)]}
func snapshot() -> Dictionary:
	return {"ammunition":scene.torpedoes.ammunition,"campaign":campaign.duplicate(true)}
func restore(value: Dictionary) -> void:
	campaign = CampaignData.normalized(value.campaign)
	scene.torpedoes.restore_ammunition(int(value.ammunition))
	scene.upgrades.reapply()
	_refresh_map_marker()
	research_changed.emit()
func _commit(value: Dictionary) -> Error:
	if not CampaignData.valid(value) or not can_write(): return ERR_INVALID_DATA
	var result: Error = scene.saves.commit_prototype({"ammunition":scene.torpedoes.ammunition,"campaign":value})
	if result==OK:
		campaign = value.duplicate(true)
		scene.upgrades.reapply()
		research_changed.emit()
	feedback = "Research allocation saved. Reassignment is free at base." if result==OK else "Change not saved; previous allocation preserved. Recover the checkpoint before retrying."
	return result
func assign(branch: String, difference: int) -> Error:
	if not ui.dock_page.visible or not scene.station.is_in_range(scene.submarine.global_position) or scene.submarine.is_physics_processing(): return ERR_UNAVAILABLE
	if branch not in ["sonar","hull"] or difference not in [-1,1]: return ERR_INVALID_PARAMETER
	var next: Dictionary = campaign.duplicate(true)
	next.ranks[branch] += difference
	return _commit(next) if CampaignData.valid(next) else ERR_UNAVAILABLE
func respec() -> Error:
	if not ui.dock_page.visible or not scene.station.is_in_range(scene.submarine.global_position) or scene.submarine.is_physics_processing(): return ERR_UNAVAILABLE
	var next: Dictionary = campaign.duplicate(true)
	next.ranks = {"sonar":0,"hull":0}
	return _commit(next)
func start_from_title() -> void:
	if scene.chapter!=null: scene.chapter.start()
	else: start()
func start() -> void:
	if not can_write(): return
	ui.title_page.hide()
	scene._route_resume_requested()
func open_option(id: String) -> void:
	returning_to_title = true
	ui.title_page.hide()
	match id:
		"input": scene.open_settings()
		"audio": scene.open_audio_settings()
		"accessibility": scene.open_accessibility()
		"help": scene.open_help()
func on_docked() -> Error:
	if scene.station._live_player()!=scene.submarine or scene.station._dock_check(scene.submarine,true).error!=OK: return ERR_UNAVAILABLE
	# Only deliberate, validated docking calls this; crossing base never restores supplies.
	var before: Dictionary = scene.station._values(scene.submarine)
	var service: Dictionary = scene.station.perform(&"all")
	scene.torpedoes.refill()
	docking_report = "Docked · Hull %.0f → %.0f · Battery %.0f → %.0f · Oxygen %.0f → %.0f · Torpedoes 10/10" % [before.hull,scene.submarine.hull_system.hull,before.battery,scene.submarine.resource_system.battery,before.oxygen,scene.submarine.resource_system.oxygen]
	if service.error not in [OK,ERR_UNAVAILABLE]: docking_report = "Docking services unavailable: "+str(service.reason)
	if scene.chapter!=null and scene.chapter.active:
		scene.route_check.sample(scene.region.base_zone.contains_world_position(scene.submarine.global_position),scene.region.point_of_interest_zone.contains_world_position(scene.submarine.global_position),0.0)
		scene.station_menu.hide()
		if scene.saves.save_current()!=OK: docking_report += "\nCHECKPOINT NOT SAVED · Recover before continuing."
		ui.show_dock()
		return OK
	if scene.research.is_completed(WRECK) and not campaign.decoded:
		var next: Dictionary = campaign.duplicate(true)
		next.decoded = true
		next.awards.append("wreck-decoded")
		if _commit(next)==OK:
			logs_decoded.emit()
			docking_report += "\nRecorder decoded · +1 research point · Next investigation dossier available."
	_reward_survey()
	if scene.narrative.can_debrief(): scene.narrative.debrief(scene.station)
	scene.station_menu.hide()
	if scene.saves!=null and scene.saves.save_current()!=OK: docking_report += "\nCHECKPOINT NOT SAVED · Recover or inspect the preserved expedition file before spending research points."
	ui.show_dock()
	return OK
func undock() -> void:
	ui.dock_page.hide()
	scene.close_station()
func _refresh_ammo() -> void:
	if _ammo_label==null: return
	var state: String = "EMPTY · DOCK TO REARM" if scene.torpedoes.ammunition==0 else ("REARMING %.1fs" % scene.torpedoes._cooldown if scene.torpedoes._cooldown>0 else "READY")
	if scene.torpedoes.ammunition>0 and scene.submarine.resource_system.battery<scene.torpedoes._rules.battery_cost: state = "LOW BATTERY"
	_ammo_label.text = "TORPEDOES %d/10 · %s" % [scene.torpedoes.ammunition,state]
func _reward_survey_deferred() -> void:
	_reward_survey.call_deferred()
func _reward_survey() -> void:
	if not can_write(): return
	var state: String = scene.missions.snapshot()[String(ShelfChapterData.OUTER)].state
	if state in ["completed","claimed"] and "outer-survey" not in campaign.awards:
		var next: Dictionary = campaign.duplicate(true)
		next.awards.append("outer-survey")
		_commit(next)
func _physics_process(delta: float) -> void:
	_refresh_ammo()
	if scene==null or not scene.submarine.is_physics_processing(): return
	if scene.chapter!=null and scene.chapter.active: return
	_clock += delta
	if scene.station.is_in_range(scene.submarine.global_position) or _clock<_defer_until or ui.modal(): return
	var id: String = ""
	var offer: bool = false
	if scene.missions.snapshot()[String(ShelfChapterData.OUTER)].state=="available":
		id = "dispatch"
		offer = true
	elif campaign.decoded and "next-signal" not in campaign.messages: id = "next-signal"
	elif scene.research.is_completed(WRECK) and "wreck-recovered" not in campaign.messages: id = "wreck-recovered"
	elif "outer-survey" in campaign.awards and "survey-complete" not in campaign.messages: id = "survey-complete"
	elif scene.discoveries.state_of(NarrativeService.SPIRES)==DiscoveryRegistry.State.DISCOVERED and "relay" not in campaign.messages: id = "relay"
	if id!="": show_transmission(id,offer)
func show_transmission(id: String, offer: bool = false) -> void:
	if id not in TRANSMISSIONS: return
	_radio_id = id
	scene.submarine.velocity = Vector2.ZERO
	scene.submarine.set_simulation_enabled(false)
	ui.show_radio(id,TRANSMISSIONS[id],offer)
func accept_transmission(id: String, offer: bool) -> void:
	if not ui.radio_page.visible or id!=_radio_id: return
	if offer:
		if scene.narrative.begin_survey()!=OK: return
	var next: Dictionary = campaign.duplicate(true)
	if id not in next.messages: next.messages.append(id)
	if _commit(next)!=OK: return
	_refresh_map_marker()
	ui.radio_page.hide()
	_defer_until = _clock+8.0
	scene.resume_route()
func defer_transmission() -> void:
	ui.radio_page.hide()
	_defer_until = _clock+25.0
	scene.resume_route()
func _refresh_map_marker() -> void:
	var accepted: bool = scene.missions.snapshot()[String(ShelfChapterData.OUTER)].state!="available"
	scene.exploration_map.canvas.reported_position = Vector2(3560,650)
	scene.exploration_map.canvas.has_report = accepted and scene.discoveries.state_of(NarrativeService.SPIRES)!=DiscoveryRegistry.State.DISCOVERED
	scene.exploration_map.canvas.queue_redraw()
func research_text(id: StringName, fallback: String) -> String:
	if id==WRECK: return decoded_text() if campaign.decoded else "ENCRYPTED FLIGHT LOGS RECOVERED\nThe damaged recorder cannot be decoded aboard NERIS. Return to Shelf Base for automatic upload and decoding."
	return fallback
func decoded_text() -> String:
	return "SURVEY 07 / DECODED EXPEDITION LOGS\n\nEngineering: power failed during the quiet run. Ballast released. Emergency grounding completed; the pressure hull held long enough to evacuate.\n\nScience: the portable receiver was removed before grounding. The crew followed a bearing into the Twilight Reef, listening for the silence between transmissions.\n\nFinal readable instruction: If the sequence stops, keep recording.\n\nNEXT DOSSIER / Twilight Reef receiver trail. The next region is not yet playable. Your findings and research points remain saved."
func archive_text() -> String:
	var lines: PackedStringArray = []
	for id: String in campaign.messages: lines.append(TRANSMISSIONS[id])
	return "\n\n".join(lines) if not lines.is_empty() else "No accepted radio assignments. Depart base to receive the expedition briefing. Accept the incoming investigation to activate its objectives."
func _setup_world() -> void:
	for decoration: Node in scene.region.get_children():
		if decoration is OuterShelfInk:
			decoration.shaded = true
			decoration.queue_redraw()
	var relief: SeascapeRelief = SeascapeRelief.new()
	scene.region.add_child(relief)
	var garden: BenthicGarden = BenthicGarden.new()
	scene.region.add_child(garden)
	scene.excavation.geometry_changed.connect(garden.refresh)
	for animal: AcousticCreature in [scene.creature,scene.predator]+scene.extension.wildlife:
		_paint_creature(animal)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/seascape_rock.gdshader")
	for rock: DestructibleRock in scene.excavation._rocks.values():
		rock.material = material
		rock.fill = rock.fill.lightened(0.12)
		rock.queue_redraw()
	var body: PackedScene = preload("res://scenes/creatures/acoustic_creature.tscn")
	var node: AcousticCreature = body.instantiate() as AcousticCreature
	node.set_script(preload("res://scripts/ai/wreck_scavenger.gd"))
	scavenger = node as WreckScavenger
	scavenger.creature_id = &"wreck-scavenger"
	scavenger.configuration = CreatureProfile.new()
	scavenger.configuration.navigation_bounds = Rect2(21000,1050,2300,320)
	scavenger.configuration.patrol_points = PackedVector2Array([Vector2(21300,1220),Vector2(21370,1220)])
	scavenger.configuration.investigate_speed = 170.0
	scavenger.position = Vector2(21300,1220)
	scavenger.player = scene.submarine
	scene.region.add_child(scavenger)
	scavenger.bind_bus(scene.get_node("AcousticBus") as AcousticBus)
	scavenger.set_suspended(not scene.submarine.is_physics_processing())
	scene.submarine.simulation_enabled_changed.connect(func(enabled: bool) -> void: scavenger.set_suspended(not enabled))
	scene.extension.wildlife.append(scavenger)
	var receiver: BlastReceiver = BlastReceiver.new()
	scavenger.add_child(receiver)
	receiver.setup(scavenger)
	scene.torpedoes._receivers.append(receiver)
	_paint_creature(scavenger)
func _paint_creature(animal: AcousticCreature) -> void:
	animal.illustrated = true
	var paint: CreaturePaint = CreaturePaint.new()
	paint.hostile = animal is PredatorCreature
	animal.add_child(paint)
	(animal.get_node("StateCaption") as Label).hide()
	animal.queue_redraw()
