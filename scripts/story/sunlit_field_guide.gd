class_name SunlitFieldGuide
extends Node
## Domain adapters, not another mission ledger. Hints/particles are temporary.
const RADIO_IDS: Array[String] = ["sunlit-map-guidance","sunlit-cavein-guidance","sunlit-search-guidance","sunlit-pressure-guidance","sunlit-recovery-guidance","sunlit-bloom-response"]
var scene: ShelfPrototype
var layout: SunlitRegionLayout
var schools: Array[AmbientFishSchool] = []
var fauna: Array[AcousticCreature] = []
var hammerhead: HammerheadCreature
var _hammer_phase: int = 0
var popup: ScientificDiscoveryPopup
var ambient: AmbientAcousticField
var _announced: Array[String] = []
var _foreign: Array[Dictionary] = []
var _dust: Array[ExcavationSediment] = []
var _enabled: bool = false
var _bubble_clock: float = 0.0

func setup(game: ShelfPrototype) -> void:
	scene = game
	layout = scene.region.get_node("SunlitRegionLayout") as SunlitRegionLayout
	popup = ScientificDiscoveryPopup.new()
	scene.get_node("UI").add_child(popup)
	popup.setup(scene)
	scene.research_log.summary_provider = func() -> String:
		return "RESEARCH XP %d · BONUS RESEARCH POINTS %d/%d · Unique records only · Historical records award no retroactive XP" % [ResearchExperienceData.total(scene.revision.campaign.science),ResearchExperienceData.points(scene.revision.campaign.science),ResearchExperienceData.RULES.maximum_extra_points] if _enabled else "Prototype research retains its original finite awards."
	scene.revision.research_changed.connect(scene.research_log.refresh_summary)
	ambient = AmbientAcousticField.new()
	ambient.name = "SunlitAmbientField"
	scene.region.add_child(ambient)
	for item: Dictionary in [{"id":"halcyon-field-generator","at":Vector2(420,80),"kind":&"mechanical","range":1400.0},{"id":"sunlit-vent-noise","at":Vector2(14000,1180),"kind":&"geological","range":1800.0}]:
		var source: AmbientSoundEmitter = AmbientSoundEmitter.new()
		source.source_id = StringName(item.id)
		source.session_id = &"sunlit-ambient"
		source.configuration = AmbientEmissionProfile.new()
		source.configuration.classification = item.kind
		source.configuration.interval_seconds = 12.0
		source.configuration.maximum_events = 256
		source.configuration.range_units = item.range
		source.configuration.strength = 65.0
		var emitter: AcousticEmitter = AcousticEmitter.new()
		emitter.name = "AcousticEmitter"
		source.add_child(emitter)
		ambient.add_child(source)
		source.position = item.at
	var ambient_result: Error = ambient.bind_bus(scene.get_node("AcousticBus") as AcousticBus)
	if ambient_result!=OK: push_error("Invalid canonical ambient field.")
	for item: Dictionary in SunlitSurveyData.STUDIES:
		if item.kind!="biological": continue
		_add_school(item.id,item.at,int(item.school),8+int(item.school)*2)
	for index: int in range(3):
		_add_school("sunlit-ambient-%d" % index,[Vector2(5200,620),Vector2(12500,400),Vector2(20700,240)][index],index,5+index)
	for child: Node in scene.region.get_children():
		if child is OuterShelfInk or child is ExpeditionWreck:
			_foreign.append({"node":weakref(child),"visible":child.visible})
	_foreign.append({"node":weakref(scene.predator),"visible":scene.predator.visible})
	_make_fauna()
	scene.excavation.geometry_changed.connect(_geometry_changed)
	scene.torpedoes.detonated.connect(_blast)
	scene.research.scan_completed.connect(_scanned)
	scene.discoveries.registry_changed.connect(_refresh)
	scene.submarine.simulation_enabled_changed.connect(_simulation)
	if scene.saves!=null: scene.saves.checkpoint_restored.connect(_restored)

func _restored() -> void:
	ambient.reset_session()
	for animal: AcousticCreature in fauna: animal.reset_session()
	_simulation(scene.submarine.is_physics_processing())
	_refresh()

func _add_school(id: String,at: Vector2,species: int,population: int) -> void:
	var school: AmbientFishSchool = AmbientFishSchool.new()
	school.name = id
	school.school_id = StringName(id)
	school.configuration = preload("res://resources/creatures/sunlit_school.tres").duplicate(false) as FishSchoolProfile
	school.configuration.species = species
	school.configuration.population = population
	school.position = at
	scene.region.add_child(school)
	var result: Error = school.setup(scene)
	if result!=OK: push_error("Invalid authored fish school: "+String(school.school_id))
	schools.append(school)

func set_enabled(value: bool) -> void:
	_enabled = value
	layout.set_enabled(value)
	for record: Dictionary in _foreign:
		var canvas: CanvasItem = record.node.get_ref() as CanvasItem
		if is_instance_valid(canvas): canvas.visible = false if value else bool(record.visible)
	for animal: AcousticCreature in scene.extension.wildlife:
		animal.visible = not value and not animal._destroyed
		animal.set_suspended(value or not scene.submarine.is_physics_processing())
	for echo: Node in scene.region.get_node("SonarTargets").get_children():
		var legacy: bool = echo.target_id in [&"overlook-marker",&"cave-marker"]
		for point: Dictionary in ShelfChapterData.POINTS:
			if echo.target_id==StringName(point.echo): legacy = true
		if legacy:
			echo.receiver.enabled = not value
			echo.visible = not value
			if value: echo.reset_reveal(scene.submarine.sonar._time)
	for id: StringName in scene.submarine.scanner._targets:
		var target: ScientificScanTarget = scene.submarine.scanner._targets[id].get_ref() as ScientificScanTarget
		if target==null: continue
		if id in [&"outer-hydrophone-record",&"outer-vent-study",&"lost-expedition-blackbox"]:
			target.scan_enabled = not value
			target.visible = not value
		if String(id).begins_with("sunlit-"):
			target.scan_enabled = value
			target.visible = value
	for point: PointOfInterest in SunlitSurveyData.points():
		for echo: Node in scene.region.get_node("SonarTargets").get_children():
			if echo.target_id==point.sonar_target_id:
				echo.receiver.enabled = value
				echo.visible = value
	scene.exploration_map.canvas.survey_enabled = value
	(scene.exploration_map.find_child("Legend",true,false) as Label).text = "▲ YOU / orientation\n⚓ HALCYON\n■ CHARTED terrain\n▧ UNSURVEYED\n○ REPORTED search area\n□ DISCOVERED landmark" if value else "▲ YOU / vessel position\n□ DISCOVERED landmark\n— PUBLIC survey boundary"
	_simulation(scene.submarine.is_physics_processing())
	_refresh()

func _simulation(enabled: bool) -> void:
	scene.predator.set_suspended(_enabled or not enabled)
	scene.predator.visible = not _enabled and not scene.predator._destroyed
	if _enabled:
		for animal: AcousticCreature in scene.extension.wildlife:
			animal.set_suspended(true)
			animal.visible = false
	for animal: AcousticCreature in fauna:
		animal.visible = _enabled and not animal._destroyed
		animal.collision_layer = 8 if _enabled and not animal._destroyed else 0
		animal.set_suspended(not _enabled or not enabled)
	if hammerhead!=null: scene.hud.bind_threat(hammerhead if _enabled else scene.predator)
	for school: AmbientFishSchool in schools:
		school.visible = _enabled
		school.receiver.enabled = enabled and _enabled

func _announce(id: String,body: String,voice: String) -> void:
	if id in _announced: return
	_announced.append(id)
	scene.revision.ui.notifications.enqueue(id,body,voice,id in ["sunlit-pressure-guidance","sunlit-recovery-guidance","sunlit-bloom-response"])

func _physics_process(delta: float) -> void:
	if not _enabled or not scene.submarine.is_physics_processing(): return
	_bubble_clock += delta
	if _bubble_clock>=9.0:
		_bubble_clock = 0.0
		if scene.submarine.global_position.x>700: scene.audio.request(&"bubble")
	var at: Vector2 = scene.submarine.global_position
	if at.x>780:
		_announce("sunlit-map-guidance","Lantern-2, we've marked the last known location of Lantern-1's emergency buoy signal on your map. The coordinates aren't exact. Open your map ("+scene.input_context.describe(&"open_map")+") and explore toward the marked search area. Charted rock is solid; hatched sectors are not yet surveyed. Select Zoom and Pan with the same menu controls.","Okafor")
	if at.x>4000 and at.x<4800 and not layout.passage_clear():
		_announce("sunlit-cavein-guidance","A fractured rockfall blocks this optional lower passage. The open-water route above it remains clear. Lantern-2 carries excavation torpedoes. This is a thick fractured plug: several well-placed blasts are needed. Face the rock and fire ("+scene.input_context.describe(&"fire_torpedo")+") to clear an opening. It must be wide enough for the entire hull. Halcyon can rearm you; the return passage stays open.","Wick")
		scene.tutorial.show_hint("torpedo")
	if SunlitSurveyData.SEARCH.has_point(at) and scene.discoveries.state_of(SunlitShallowsData.POI)==DiscoveryRegistry.State.HIDDEN:
		_announce("sunlit-search-guidance","We've reached the last reported coordinates, but the damaged reflector is sheltered by rock. Explore beneath the overhang and change your depth; a sweep above the ridge cannot reach it. From inside a clear channel, try an active sonar ping ("+scene.input_context.describe(&"sonar_ping")+"). The buoy's acoustic reflector may still respond. The circle is approximate: move within it if the first pulse misses.","Wick")
	if SunlitSurveyData.VENT.has_point(at) and scene.submarine.damage_system.warning_state!=SubmarineDamageSystem.WarningState.SAFE:
		_announce("sunlit-pressure-guidance","Caution. We're approaching Lantern-2's current rated operating depth. Check the rating beside your depth readout. I recommend ascending. This shaft is optional; follow the same open passage upward. Pressure damage begins only below the fitted rating, after the existing grace period.","Wick")
	if scene.submarine.hull_system.hull<=0:
		_announce("sunlit-recovery-guidance","Hull integrity is depleted. Pause and Continue the last safe expedition checkpoint, or Restart Test Route. Permanent science, story choices and cleared terrain remain archived. This prototype does not add a death penalty or erase records.","Wick")
	for effect: ExcavationSediment in _dust:
		if is_instance_valid(effect): effect.advance(delta)
	_dust = _dust.filter(func(effect: ExcavationSediment) -> bool: return is_instance_valid(effect) and not effect.is_queued_for_deletion())
	if layout.passage_clear() and scene.discoveries.state_of(SunlitSurveyData.CLEARED)==DiscoveryRegistry.State.HIDDEN: _geometry_changed()

func _geometry_changed() -> void:
	if not _enabled or not layout.passage_clear(): return
	if scene.discoveries.state_of(SunlitSurveyData.CLEARED)==DiscoveryRegistry.State.HIDDEN:
		scene.discoveries.discover(SunlitSurveyData.CLEARED,&"excavation/swept-clearance")
	_refresh()

func _blast(_id: StringName,origin: Vector2) -> void:
	if not _enabled or origin.distance_to(SunlitSurveyData.GATE.get_center())>250 or _dust.size()>=2: return
	var effect: ExcavationSediment = ExcavationSediment.new()
	if scene.settings.snapshot().accessibility.reduced_particles:
		effect.free()
		return
	effect.reduced = scene.settings.snapshot().accessibility.reduced_motion
	scene.region.add_child(effect)
	effect.global_position = origin
	_dust.append(effect)

func _scanned(id: StringName) -> void:
	if not _enabled: return
	var award: int = ResearchExperienceData.RULES.award_for(id) if String(id) in scene.revision.campaign.science.credited else 0
	popup.show_record(id,award)
	_refresh()

func review_nearby() -> bool:
	if not _enabled or scene.submarine.scanner.snapshot().active_id!=&"" or scene.submarine.scanner.candidate_id()!=&"": return false
	for id: StringName in scene.research.completed_ids():
		if scene.submarine.scanner._known(id) and scene.submarine.scanner._in_range(id):
			popup.show_record(id,0)
			return true
	return false

func _refresh() -> void:
	if scene==null: return
	var canvas: ExplorationMapCanvas = scene.exploration_map.canvas
	canvas.player_direction = scene.submarine.facing_direction()
	canvas.survey_polygons.clear()
	canvas.charted.clear()
	if not _enabled: return
	canvas.charted.append(Rect2(120,0,4880,1140))
	var regions: Array[Dictionary] = [
		{"bounds":Rect2(5000,0,3500,1140),"ids":[SunlitSurveyData.CLEARED,&"sunlit-silver-shoal-poi",&"sunlit-mineral-terrace-poi"]},
		{"bounds":Rect2(8500,0,3500,1140),"ids":[&"sunlit-amber-darter-poi",&"sunlit-basalt-arch-poi"]},
		{"bounds":Rect2(12000,0,5000,1140),"ids":[&"sunlit-blue-grazer-poi",&"sunlit-vent-survey-poi"]},
		{"bounds":Rect2(17000,0,4920,1140),"ids":[&"sunlit-sediment-fan-poi",SunlitShallowsData.POI]}]
	for section: Dictionary in regions:
		for id: StringName in section.ids:
			if scene.discoveries.state_of(id)==DiscoveryRegistry.State.DISCOVERED:
				canvas.charted.append(section.bounds)
				break
	if scene.discoveries.state_of(&"sunlit-vent-survey-poi")==DiscoveryRegistry.State.DISCOVERED: canvas.charted.append(SunlitSurveyData.VENT)
	var polygons: Array[PackedVector2Array] = SunlitSurveyData.terrain()
	polygons.append_array(layout.gate.pieces)
	for mouth: DestructibleRock in layout.tunnels: polygons.append_array(mouth.pieces)
	for polygon: PackedVector2Array in polygons:
		for section: Rect2 in canvas.charted:
			canvas.survey_polygons.append_array(Geometry2D.intersect_polygons(polygon,SunlitSurveyData._rect(section)))
	canvas.queue_redraw()
	scene.exploration_map.refresh()
	scene.research_log.refresh_summary()
	if scene.mission_tracker!=null: scene.mission_tracker.refresh()

func _make_fauna() -> void:
	for item: Dictionary in [{"id":&"sunlit-moray","kind":0,"bounds":Rect2(8270,550,450,220),"points":PackedVector2Array([Vector2(8380,650),Vector2(8600,690)])},{"id":&"sunlit-turtle","kind":1,"bounds":Rect2(7280,250,650,170),"points":PackedVector2Array([Vector2(7400,335),Vector2(7750,335)])},{"id":&"sunlit-hammerhead","kind":2}]:
		var animal: AcousticCreature = preload("res://scenes/creatures/acoustic_creature.tscn").instantiate() as AcousticCreature
		if item.kind==2:
			animal.set_script(preload("res://scripts/ai/hammerhead_creature.gd"))
			hammerhead = animal as HammerheadCreature
			animal.configuration = preload("res://resources/creatures/sunlit_hammerhead.tres")
		else:
			animal.configuration = CreatureProfile.new()
			animal.configuration.navigation_bounds = item.bounds
			animal.configuration.patrol_points = item.points
			animal.configuration.patrol_speed = 32 if item.kind==1 else 48
		animal.creature_id = item.id
		animal.position = animal.configuration.patrol_points[0]
		scene.region.add_child(animal)
		var bind_result: Error = animal.bind_bus(scene.get_node("AcousticBus") as AcousticBus)
		if bind_result!=OK: push_error("Invalid authored marine animal: "+String(animal.creature_id))
		var blast: BlastReceiver = BlastReceiver.new()
		animal.add_child(blast)
		blast.setup(animal)
		scene.torpedoes._receivers.append(blast)
		if animal is HammerheadCreature:
			var player_result: Error = hammerhead.setup_player(scene.submarine)
			if player_result!=OK: push_error("Hammerhead player binding failed.")
			hammerhead.threat_changed.connect(_hammer_changed)
		var paint: MarineAnimalPaint = MarineAnimalPaint.new()
		animal.add_child(paint)
		paint.setup(animal,scene,item.kind)
		(animal.get_node("StateCaption") as Label).hide()
		animal.set_suspended(true)
		animal.hide()
		fauna.append(animal)

func _hammer_changed() -> void:
	if hammerhead.threat.phase==_hammer_phase: return
	_hammer_phase = hammerhead.threat.phase
	if scene.audio!=null:
		scene.audio.request(&"predator_alert" if _hammer_phase==PredatorState.Phase.ALERT else (&"predator_pursue" if _hammer_phase==PredatorState.Phase.PURSUE else &"retreat"))
