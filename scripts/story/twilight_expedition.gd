class_name TwilightExpedition
extends Node
## Scene-owned chapter adapter. No second mission ledger, timer save or reward store.
var scene: ShelfPrototype
var journey: ChapterJourney
var sentinel: TwilightSentinel
var contact: AmbientSoundEmitter
var health: BlastReceiver
var art: Sprite2D
var net: Node2D
var props: Node2D
var enabled: bool = false
var action: StringName = &""
var elapsed: float = 0.0
var pending_loss: bool = false
var glimpse_seen: bool = false
var _phase: float = 0.0
var _material: ShaderMaterial
var _previous_gate: Callable
var _echoes: Array[SonarRevealTarget] = []
const ACTION_SECONDS: float = 6.0
const ACTION_RADIUS: float = 240.0

func setup(game: ShelfPrototype,owner_journey: ChapterJourney) -> void:
	scene = game
	journey = owner_journey
	props = Node2D.new()
	journey.layout.add_child(props)
	_build_subjects()
	_build_sentinel()
	journey.habitat._add_source(&"twilight-net-contact",TwilightShelfData.NET,&"marine_life",14.0)
	contact = journey.habitat.ambient.get_child(journey.habitat.ambient.get_child_count()-1) as AmbientSoundEmitter
	var registration_32: Error = journey.habitat.ambient.bind_bus(scene.get_node("AcousticBus") as AcousticBus)
	if registration_32!=OK: push_error("Twilight registration failed: "+error_string(registration_32))
	_previous_gate = scene.research.completion_gate
	scene.research.completion_gate = _scan_gate
	scene.research.scan_completed.connect(_scanned)
	scene.story.choice_applied.connect(_decided)
	scene.saves.checkpoint_restored.connect(reset_session)
	scene.missions.missions_changed.connect(refresh)
	scene.submarine.simulation_enabled_changed.connect(_simulation)
	scene.settings.settings_changed.connect(refresh)
	set_enabled(false)

func _build_subjects() -> void:
	for item: Dictionary in TwilightShelfData.all_records():
		var echo: SonarRevealTarget = preload("res://scenes/props/sonar_reveal_target.tscn").instantiate() as SonarRevealTarget
		echo.target_id = StringName(item.id+"-echo")
		echo.caption = item.title
		echo.requires_clear_path = item.get("clear_path",false)
		echo.position = item.at
		echo.revealed_for_ping.connect(func(_event: StringName) -> void: (echo.get_node("Caption") as Label).hide())
		props.add_child(echo)
		(echo.get_node("Caption") as Label).hide()
		var registration_52: Error = echo.bind_bus(scene.get_node("AcousticBus") as AcousticBus)
		if registration_52!=OK: push_error("Twilight registration failed: "+error_string(registration_52))
		var registration_53: Error = scene.submarine.sonar.listen_to(echo)
		if registration_53!=OK: push_error("Twilight registration failed: "+error_string(registration_53))
		var registration_54: Error = scene.discoveries.connect_sonar_target(echo)
		if registration_54!=OK: push_error("Twilight registration failed: "+error_string(registration_54))
		_echoes.append(echo)
		if item.id=="twilight-net-survey": continue
		var marker: Sprite2D = Sprite2D.new()
		marker.texture = TwilightShelfData.subject_texture(StringName(item.id))
		var width: float = 210.0 if item.id=="twilight-whaler-marking" else (130.0 if item.id in ["twilight-thermal-crust","twilight-ballast-pocket","twilight-cargo-timber"] else 100.0)
		marker.scale = Vector2.ONE*width/marker.texture.get_width()
		marker.position = item.at
		marker.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		props.add_child(marker)
	# Interrupted, sagging physical cable, not a perfect quest trail.
	for points: PackedVector2Array in [PackedVector2Array([Vector2(35350,1630),Vector2(35680,1720),Vector2(35950,1940)]),PackedVector2Array([Vector2(35990,1980),Vector2(36160,2200),Vector2(36070,2470),Vector2(35800,2820)])]:
		var cable: Line2D = Line2D.new()
		var curve: Curve2D = Curve2D.new()
		curve.bake_interval = 12
		for index: int in range(points.size()):
			var tangent: Vector2 = (points[mini(index+1,points.size()-1)]-points[maxi(0,index-1)])*0.17
			curve.add_point(points[index],-tangent,tangent)
		cable.points = curve.get_baked_points()
		cable.width = 4
		cable.default_color = Color("3f5550")
		cable.antialiased = true
		props.add_child(cable)

func _build_sentinel() -> void:
	var body: AcousticCreature = preload("res://scenes/creatures/acoustic_creature.tscn").instantiate() as AcousticCreature
	# Retain the existing scene body's children while specializing its trapped motion.
	body.set_script(preload("res://scripts/story/twilight_sentinel.gd"))
	sentinel = body as TwilightSentinel
	sentinel.creature_id = &"twilight-net-sentinel"
	sentinel.position = TwilightShelfData.NET
	var rules: CreatureProfile = CreatureProfile.new()
	rules.navigation_bounds = Rect2(35000,2820,3500,620)
	rules.grid_spacing = 100
	rules.patrol_speed = 50
	rules.return_speed = 55
	rules.patrol_points = PackedVector2Array([TwilightShelfData.NET,Vector2(35800,2940)])
	rules.hearing.accepted_event_types = [&"active_sonar",&"explosion"]
	rules.event_priorities = {&"active_sonar":20,&"explosion":30}
	sentinel.configuration = rules
	sentinel.illustrated = true
	sentinel.damageable = true
	journey.layout.add_child(sentinel)
	(sentinel.get_node("StateCaption") as Label).hide()
	var registration_98: Error = sentinel.bind_bus(scene.get_node("AcousticBus") as AcousticBus)
	if registration_98!=OK: push_error("Twilight registration failed: "+error_string(registration_98))
	health = BlastReceiver.new()
	sentinel.add_child(health)
	health.setup(sentinel)
	health.destroyed.connect(_killed)
	scene.torpedoes._receivers.append(health)
	art = Sprite2D.new()
	art.texture = preload("res://assets/art/twilight/sentinel.png")
	art.scale = Vector2.ONE*360.0/art.texture.get_width()
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_material = ShaderMaterial.new()
	_material.shader = preload("res://assets/shaders/fauna_swim.gdshader")
	_material.set_shader_parameter("mode",1)
	_material.set_shader_parameter("cell",Vector4(0,0,1,1))
	art.material = _material
	sentinel.add_child(art)
	net = Node2D.new()
	net.position = TwilightShelfData.NET
	props.add_child(net)
	net.z_index = 3
	var mesh_art: Sprite2D = Sprite2D.new()
	mesh_art.texture = preload("res://assets/art/twilight/retrieval_net.png")
	mesh_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mesh_art.scale = Vector2.ONE*460.0/mesh_art.texture.get_width()
	net.add_child(mesh_art)

func set_enabled(value: bool) -> void:
	enabled = value
	props.visible = value
	for item: Dictionary in TwilightShelfData.all_records():
		(scene.region.get_node(String(item.id)) as ScientificScanTarget).scan_enabled = value
	for echo: SonarRevealTarget in _echoes: echo.receiver.enabled = value
	if not value: cancel_action()
	refresh()

func _simulation(simulating: bool) -> void:
	sentinel.set_suspended(not enabled or not simulating)

func refresh() -> void:
	if sentinel==null: return
	var captured: bool = scene.story.has_decision(TwilightShelfData.CAPTURE)
	var lost: bool = scene.story.has_decision(TwilightShelfData.LOST) or scene.story.has_flag(&"zone2-released-sentinel-lost") or pending_loss
	sentinel.released = scene.story.has_decision(TwilightShelfData.RELEASE)
	sentinel.visible = enabled and not captured and not lost
	sentinel.collision_layer = 8 if enabled and not captured and not lost else 0 # Player sweeps terrain only; torpedoes can hit this animal.
	sentinel.damageable = enabled and not captured and not lost
	health.enabled = sentinel.damageable
	if captured or lost:
		contact._halted = true
		contact.bind_bus(null)
	elif enabled and contact.emitter.get_bus()==null:
		contact.bind_bus(scene.get_node("AcousticBus") as AcousticBus)
	net.visible = enabled and not sentinel.released and not captured
	net.modulate = Color("818a84") if captured or lost else Color.WHITE
	_material.set_shader_parameter("amount",0.0 if scene.settings.snapshot().accessibility.reduced_motion else 1.0)
	_simulation(scene.submarine.is_physics_processing())
	if scene.mission_tracker!=null: scene.mission_tracker.refresh()

func reset_session() -> void:
	cancel_action()
	pending_loss = false
	sentinel.reset_session()
	health.reset_session()
	_phase = 0.0
	glimpse_seen = false
	refresh()

func near_net() -> bool:
	return enabled and scene.submarine.global_position.distance_to(TwilightShelfData.NET)<=ACTION_RADIUS

func cancel_action() -> void:
	action = &""
	elapsed = 0.0

func interact() -> bool:
	if not near_net(): return false
	if action!=&"":
		cancel_action()
		return true
	if pending_loss:
		_killed()
		return true
	if not scene.research.is_completed(&"twilight-net-survey"): return false
	_pause()
	if scene.story.resolved(TwilightShelfData.ENCOUNTER):
		_show_response()
	else:
		scene.revision.ui.show_story_page("A LIVING CONTACT / TETHYS DRIFT NET","The scan is archived. You can loosen the net or secure its powered cradle for a living delivery. You may leave and decide later.\n\nOkafor: Give it room. Let us see what it chooses.\n\nCrane: A living specimen could answer questions the recording cannot.","Carefully release the sentinel",begin_release,&"ReleaseSentinel",_leave)
		scene.revision.ui.add_story_option("Secure a living specimen for Crane",confirm_capture,&"CaptureSentinel")
	return true

func _pause() -> void:
	scene.submarine.velocity = Vector2.ZERO
	scene.submarine.set_simulation_enabled(false)
	scene.revision.ui.notifications.collapse()

func _leave() -> void:
	scene.revision.ui.radio_page.hide()
	scene.resume_route()

func begin_release() -> void:
	_start(TwilightShelfData.RELEASE)

func confirm_capture() -> void:
	scene.revision.ui.show_story_page("CONFIRM LIVE COLLECTION","The cradle will close around the living animal. Its light will be removed from this habitat. Bring it to Halcyon for the one-time specimen allowance and +100-unit sonar calibration. Release remains available until you start securing it.","Secure the living cradle",begin_capture,&"ConfirmCaptureSentinel",_leave)

func begin_capture() -> void:
	_start(TwilightShelfData.CAPTURE)

func _start(id: StringName) -> void:
	if not near_net() or pending_loss or scene.story.resolved(TwilightShelfData.ENCOUNTER) or not scene.research.is_completed(&"twilight-net-survey"): return
	action = id
	elapsed = 0.0
	_leave()

func advance(delta: float) -> void:
	if not enabled or not scene.submarine.is_physics_processing() or not is_finite(delta) or delta<0 or delta>1: return
	if not scene.settings.snapshot().accessibility.reduced_motion: _phase += delta
	_material.set_shader_parameter("phase",_phase)
	if absf(sentinel.velocity.x)>1: art.flip_h = sentinel.velocity.x<0
	contact.global_position = sentinel.global_position
	_observe_glimpse()
	if action==&"": return
	if not near_net() or pending_loss or scene.story.resolved(TwilightShelfData.ENCOUNTER):
		cancel_action()
		return
	elapsed = minf(ACTION_SECONDS,elapsed+delta)
	if elapsed+0.000000001>=ACTION_SECONDS:
		var id: StringName = action
		cancel_action()
		var result: Error = scene.story.apply_choice(id)
		if result!=OK:
			scene.revision.ui.notifications.enqueue("twilight-choice-save-failed","The operation was not recorded. No decision or allowance was granted. Recover the checkpoint and try again.","Wick")

func _observe_glimpse() -> void:
	# The actual net-bound animal, never a duplicate actor/event or a discovery reward.
	if glimpse_seen or scene.story.resolved(TwilightShelfData.ENCOUNTER) or scene.research.is_completed(&"twilight-net-survey") or not sentinel.visible: return
	if scene.submarine.global_position.distance_to(sentinel.global_position)>900: return
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(scene.submarine.global_position,sentinel.global_position,1)
	if not scene.submarine.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): return
	glimpse_seen = true
	scene.revision.ui.notifications.enqueue("twilight-first-light","A long light contracts beneath the eastern ledge. It stays beside the same patch of water. Approach quietly; no weapon is needed.","Wick")

func _physics_process(delta: float) -> void:
	advance(delta)

func prompt() -> String:
	if not near_net(): return ""
	var binding: String = scene.input_context.describe(&"interact")
	if action!=&"": return "%s %.0f%% · %s cancels" % ["RELEASING" if action==TwilightShelfData.RELEASE else "SECURING",elapsed/ACTION_SECONDS*100,binding]
	if pending_loss: return binding+" · Record casualty report / save retry"
	if not scene.research.is_completed(&"twilight-net-survey"):
		if scene.submarine.global_position.distance_to(TwilightShelfData.NET)>190: return "Approach the net to scan"
		return binding+" · Scan the net and living contact"
	return binding+" · "+("Review encounter record" if scene.story.resolved(TwilightShelfData.ENCOUNTER) else "Release or collect the trapped animal")

## Retries a casualty record whose checkpoint write failed. Returns true when no casualty
## is pending afterwards. Used before Halcyon recovery, which cannot save past it.
func retry_casualty_record() -> bool:
	if pending_loss:
		_killed()
	return not pending_loss

## The story snapshot that records the pending casualty, without committing it: {"error", "data"}.
## Same choice as _killed(): a released animal sets the casualty flag, otherwise the LOST decision.
## Halcyon recovery writes this inside its own checkpoint when the hull is already destroyed.
func pending_casualty_story() -> Dictionary:
	if not pending_loss: return {"error": ERR_DOES_NOT_EXIST}
	if scene.story.has_decision(TwilightShelfData.RELEASE): return scene.story.preview_flag(&"zone2-released-sentinel-lost")
	return scene.story.preview_choice(TwilightShelfData.LOST)

func _killed() -> void:
	if not enabled or scene.story.has_decision(TwilightShelfData.CAPTURE) or scene.story.has_decision(TwilightShelfData.LOST) or scene.story.has_flag(&"zone2-released-sentinel-lost"): return
	pending_loss = true
	cancel_action()
	var result: Error = scene.story.set_flag(&"zone2-released-sentinel-lost") if scene.story.has_decision(TwilightShelfData.RELEASE) else scene.story.apply_choice(TwilightShelfData.LOST)
	if result==OK:
		pending_loss = false
		if scene.story.has_flag(&"zone2-released-sentinel-lost"): scene.revision.ui.notifications.enqueue("twilight-released-casualty","The released sentinel has been killed. The loss is recorded; that animal cannot guide a future expedition. No further research allowance is due.","Wick")
	refresh()

func _scan_gate(id: StringName) -> Error:
	if not TwilightShelfData.knows(id): return _previous_gate.call(id) if _previous_gate.is_valid() else OK
	if not enabled or not scene.submarine.scanner._in_range(id): return ERR_UNAVAILABLE
	var proposed: Array[StringName] = scene.research.completed_ids()
	proposed.append(id)
	return scene.saves.commit_research_checkpoint(proposed)

func _scanned(id: StringName) -> void:
	if not enabled or not TwilightShelfData.knows(id): return
	var item: Dictionary = TwilightShelfData.record(id)
	scene.revision.ui.notifications.enqueue(String(id),record_text(StringName(item.id)),"Mara" if "mara-log" in String(id) else "Wick")
	journey.refresh()

func _decided(_id: StringName,encounter: StringName) -> void:
	if encounter!=TwilightShelfData.ENCOUNTER: return
	refresh()
	if enabled:
		_pause()
		_show_response()

func _show_response() -> void:
	var id: StringName = TwilightShelfData.RELEASE if scene.story.has_decision(TwilightShelfData.RELEASE) else (TwilightShelfData.CAPTURE if scene.story.has_decision(TwilightShelfData.CAPTURE) else TwilightShelfData.LOST)
	scene.revision.ui.show_story_page("THE WATER ANSWERS",scene.story.definition(id).response_text,"Return to piloting",_leave,&"ReturnFromSentinel",_leave)

func guidance() -> String:
	if concluded(): return "✓ Expedition archived · Drowned Caves investigation pending"
	# Offer the western evidence when the pilot chooses that branch; never gate it on cable order.
	if scene.submarine.global_position.x<33000 and not scene.research.is_completed(&"twilight-whaler-marking"): return "◇ Examine markings in the western whaler gallery"
	if not scene.research.is_completed(&"twilight-severed-cable"): return "◇ Follow the broken sensor line · examine its cut"
	if not scene.research.is_completed(&"twilight-mara-log-one"): return "◇ Recover the survey instrument below the cable break"
	if not scene.research.is_completed(&"twilight-whaler-marking"): return "◇ Examine markings in the western whaler gallery"
	if not scene.research.is_completed(&"twilight-net-survey"): return "◇ Investigate the living contact in the lower eastern basin"
	if not scene.story.resolved(TwilightShelfData.ENCOUNTER): return "◇ Return to the net · decide how to respond"
	return "◇ Evidence secured · ascent tether for Halcyon debrief"

func concluded() -> bool:
	return scene.missions.snapshot().get(String(TwilightShelfData.MISSION),{}).get("state")=="claimed"

func entries() -> Array[NarrativeEntry]:
	var result: Array[NarrativeEntry] = []
	var opening: NarrativeEntry = NarrativeEntry.new()
	opening.stable_id = &"twilight-expedition-orders"
	opening.title = "Twilight Shelf / the severed line"
	opening.text = "Lantern-2 / 350 m. Trace the broken eastern sensor cable and investigate the western wreck gallery in either order. Recover evidence, record without translating and return through the ascent tether. Two central chimneys join a cross-gallery with blind cargo pockets. Optional observations and detached loggers do not block the expedition. Halcyon services and research refitting remain available."
	result.append(opening)
	for item: Dictionary in TwilightShelfData.all_records():
		if not scene.research.is_completed(StringName(item.id)): continue
		var entry: NarrativeEntry = NarrativeEntry.new()
		entry.stable_id = StringName(item.id)
		entry.title = item.title
		entry.text = record_text(StringName(item.id))
		result.append(entry)
	if scene.story.resolved(TwilightShelfData.ENCOUNTER):
		var choice: NarrativeEntry = NarrativeEntry.new()
		choice.stable_id = &"twilight-encounter-record"
		choice.title = "The net / field decision"
		var id: StringName = TwilightShelfData.RELEASE if scene.story.has_decision(TwilightShelfData.RELEASE) else (TwilightShelfData.CAPTURE if scene.story.has_decision(TwilightShelfData.CAPTURE) else TwilightShelfData.LOST)
		choice.text = scene.story.definition(id).response_text
		result.append(choice)
	if concluded():
		var debrief: NarrativeEntry = NarrativeEntry.new()
		debrief.stable_id = &"twilight-debrief"
		debrief.title = "Halcyon / Twilight expedition debrief"
		debrief.text = debrief_text()
		result.append(debrief)
	return result

func show_debrief() -> void:
	if not journey.at_station(): return
	scene.revision.ui.dock_page.hide()
	var eligible: bool = scene.missions.snapshot()[String(TwilightShelfData.MISSION)].state=="completed"
	scene.revision.ui.show_story_page("HALCYON / THE SEVERED LINE",debrief_text(),"Archive expedition / receive allowance" if eligible else "Return to operations",_claim_debrief if eligible else _back_to_station,&"SubmitTwilight",_back_to_station)

func _claim_debrief() -> void:
	if not concluded() and scene.missions.claim(TwilightShelfData.MISSION)!=OK:
		scene.revision.ui.add_story_notice("Debrief not saved. Records and allocations are unchanged. Return with all required evidence or recover the checkpoint and retry.")
		return
	_back_to_station()

func _back_to_station() -> void:
	scene.revision.ui.radio_page.hide()
	scene.revision.ui.show_dock()

func debrief_text() -> String:
	var state: String = scene.missions.snapshot()[String(TwilightShelfData.MISSION)].state
	if state not in ["completed","claimed"]: return "The investigation is still open. "+guidance()+". Your records and the ascent tether remain available. Detached optional loggers are not required."
	var outcome: String = "Okafor: You gave it room to choose. Preserve that in the report."
	if scene.story.has_flag(&"zone2-released-sentinel-lost"): outcome = "Okafor: The released animal was subsequently killed. Record the loss; it cannot be our future guide. No specimen allowance is due."
	elif scene.story.has_decision(TwilightShelfData.CAPTURE): outcome = "Crane: The living cradle has reached Halcyon. The specimen allowance is 1 research point; the unique sonar calibration adds 100 units of range. Ping cost and cooldown remain unchanged."
	elif scene.story.has_decision(TwilightShelfData.LOST): outcome = "Okafor: The animal died. Archive the loss with the evidence. There is no live specimen allowance or calibration."
	return "Wick: Sensor cuts, Mara's instrument log and the whaler's markings are archived. They suggest a pattern; they do not explain it.\n\n"+outcome+"\n\nOkafor: Mara was watching the line, not just listening to it. The Drowned Caves are the next place to investigate.\n\nCrane: Prepare the evidence before another descent.\n\nChapter acknowledgement: 2 research points, once. The Drowned Caves are not playable in this build."

func log_text() -> String:
	var parts: PackedStringArray = []
	for entry: NarrativeEntry in entries(): parts.append(entry.title+"\n"+entry.text)
	return "\n\n".join(parts)

func record_text(id: StringName) -> String:
	if id==&"twilight-net-survey" and (scene.story.has_decision(TwilightShelfData.LOST) or scene.story.has_flag(&"zone2-released-sentinel-lost")):
		return "Tethys drift net / casualty record. The luminous animal was killed by a weapon impact. Net construction and the loss are recorded; no living specimen can be delivered. Other evidence remains recoverable."
	return TwilightShelfData.record(id).get("text","")


func echoes() -> Array[SonarRevealTarget]:
	return _echoes
