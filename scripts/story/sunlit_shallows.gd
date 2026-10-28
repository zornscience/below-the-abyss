class_name SunlitShallows
extends Node
## Canonical presentation and interaction adapter. Mission/research/story own all progress.
const DATA: NarrativeCatalog = preload("res://resources/story/sunlit_narrative.tres")
var scene: ShelfPrototype
var active: bool = false
var buoy: EmergencyBuoyVisual
var dressing: SunlitDressing
var departure: HalcyonDeparture
var _water_color: Color
var boundary: StaticBody2D
var _needs_rebase: bool = false
var _previous_scan_gate: Callable
func setup(owner_scene: ShelfPrototype) -> void:
	scene = owner_scene
	assert(DATA.is_valid())
	_water_color = (scene.region.get_node("Water") as Polygon2D).color
	dressing = SunlitDressing.new()
	dressing.z_index = -2
	scene.region.add_child(dressing)
	dressing.hide()
	departure = HalcyonDeparture.new()
	departure.name = "HalcyonDeparture"
	scene.region.add_child(departure)
	departure.hide()
	buoy = EmergencyBuoyVisual.new()
	buoy.position = Vector2(3500,620)
	scene.region.add_child(buoy)
	boundary = StaticBody2D.new()
	boundary.collision_layer = 0
	boundary.collision_mask = 2
	scene.region.add_child(boundary)
	for rectangle: Rect2 in [Rect2(120,800,3860,1000),Rect2(3900,220,80,580)]:
		var collision: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = rectangle.size
		collision.shape = shape
		collision.position = rectangle.get_center()
		boundary.add_child(collision)
		var silhouette: Polygon2D = Polygon2D.new()
		silhouette.polygon = PackedVector2Array([rectangle.position,Vector2(rectangle.end.x,rectangle.position.y),rectangle.end,Vector2(rectangle.position.x,rectangle.end.y)])
		silhouette.color = Color("12313d")
		boundary.add_child(silhouette)
	boundary.hide()
	var sign: Label = Label.new()
	sign.position = Vector2(3480,742)
	sign.text = "200 m SURVEY LIMIT\nTwilight Shelf · future expedition"
	UiTypography.style(sign,&"secondary")
	boundary.add_child(sign)
	dressing.configure(scene.region,boundary,[scene.creature,scene.predator])
	scene.submarine.simulation_enabled_changed.connect(dressing.set_simulating)
	scene.excavation.geometry_changed.connect(dressing.refresh_surfaces)
	_previous_scan_gate = scene.research.completion_gate
	scene.research.completion_gate = _before_scan_completion
	scene.research.scan_completed.connect(_scan_completed)
	scene.story.choice_applied.connect(_choice_applied)
	scene.missions.missions_changed.connect(_refresh)
	scene.missions.records_restored.connect(_refresh)
	if scene.saves!=null: scene.saves.checkpoint_restored.connect(_refresh)
	scene.revision.ui.show_title()
	_refresh()
func state() -> String:
	return String(scene.missions.snapshot()[String(SunlitShallowsData.MISSION)].state)
func entry(id: StringName) -> NarrativeEntry:
	for item: Resource in DATA.entries:
		if item.stable_id==id: return item.duplicate(true) as NarrativeEntry
	return null
func primary_title() -> String:
	return "Begin The Sunlit Shallows" if state()=="available" else "Continue The Sunlit Shallows"
func start() -> void:
	if not scene.revision.can_write(): return
	var saved: Dictionary = scene.saves._state.player
	var at: Vector2 = Vector2(saved.position[0],saved.position[1])
	_needs_rebase = state()=="available" or not SunlitShallowsData.BOUNDS.has_point(at)
	if _needs_rebase:
		show_briefing()
	else:
		_activate(true)
		scene.revision.ui.title_page.hide()
		scene.revision.start()
		scene.missions.reconcile()
		scene.narrative._silent_refresh()
func show_briefing() -> void:
	scene.revision.ui.title_page.hide()
	var body: String = entry(&"sunlit-arrival").text
	if scene.saves.has_checkpoint(): body += "\n\nThis expedition launches from Halcyon. Existing observations, choices and technology remain archived; accepting replaces the vessel's departure checkpoint."
	scene.revision.ui.show_story_page("THE SUNLIT SHALLOWS / HALCYON",body,"Accept first dive" if state()=="available" else "Resume from Halcyon",launch,&"LaunchSunlit",cancel_briefing)
	scene.revision.ui.add_story_option("Ask Okafor about the anomalies",ask_okafor,&"AskOkafor")
func ask_okafor() -> void:
	scene.revision.ui.show_story_page("OKAFOR / HALCYON RADIO",entry(&"sunlit-anomalies").text,"Back to briefing",show_briefing,&"BackBriefing",show_briefing)
func cancel_briefing() -> void:
	if active and state()=="available": _activate(false)
	scene.revision.ui.radio_page.hide()
	scene.revision.ui.show_title()
func launch() -> void:
	if not scene.revision.ui.radio_page.visible or not scene.revision.can_write(): return
	if scene.saves.new_expedition()!=OK:
		scene.revision.ui.add_story_notice("Launch not saved. Recover the existing checkpoint before retrying.")
		return
	_activate(true)
	if state()=="available" and scene.missions.accept(SunlitShallowsData.MISSION)!=OK:
		scene.revision.ui.add_story_notice("Mission not accepted. Records retained; recover or retry the save.")
		return
	scene.revision.ui.radio_page.hide()
	scene.revision.start()
	scene.missions.reconcile()
func start_prototype() -> void:
	_activate(false)
	scene.revision.ui.title_page.hide()
	scene.revision.start()
func _activate(value: bool) -> void:
	active = value
	dressing.visible = value
	departure.visible = value
	(scene.region.get_node("Water") as Polygon2D).color = Color("123643") if value else _water_color
	boundary.visible = value
	boundary.collision_layer = 1 if value else 0
	(scene.hud.identity_container().get_node("Vessel") as Label).text = "LANTERN-2" if value else "NERIS / 01"
	scene.missions.progress_filter = _is_chapter if value else Callable()
	scene.narrative.entries_provider = entries if value else Callable()
	scene.narrative.guidance_provider = guidance if value else Callable()
	scene.narrative.conclusion_provider = concluded if value else Callable()
	scene.narrative.debrief_ready_provider = can_debrief if value else Callable()
	scene.narrative.debrief_provider = debrief if value else Callable()
	scene.exploration_map.presentation_bounds = SunlitShallowsData.BOUNDS if value else Rect2()
	scene.exploration_map.canvas.report_caption = "BUOY SEARCH AREA · HALCYON" if value else "LAST CONTACT · BASE REPORT"
	scene.region.camera_bounds = Rect2i(0,0,3900,800) if value else ShelfChapterData.BOUNDS
	scene.region.configure_camera(scene.submarine.get_node("Camera2D") as Camera2D)
	(scene.submarine.get_node("Camera2D") as Camera2D).reset_smoothing()
	scene.exploration_map.refresh()
	scene.narrative.presentation_changed()
	for node: Node in scene.region.get_children():
		if node is StationIllustration:
			node.visible = not value
			node.station_name = "HALCYON" if value else "SHELF BASE"
			node.queue_redraw()
	(scene.route_menu.get_node("%Brief") as Label).text = entry(&"sunlit-orders").text if value else "Prototype expedition / NERIS and Shelf Base. Earlier records remain archived."
	_refresh()
func _is_chapter(id: StringName) -> bool:
	return id==SunlitShallowsData.MISSION
func concluded() -> bool:
	return state()=="claimed"
func can_debrief() -> bool:
	return state()=="completed"
func debrief(station: ServiceStation) -> Error:
	if not active or station!=scene.station or not can_debrief(): return ERR_UNAVAILABLE
	var result: Error = station.mission_action(&"claim",SunlitShallowsData.MISSION)
	if result==OK: _refresh()
	return result
func show_debrief() -> void:
	if not active or not scene.revision.ui.dock_page.visible: return
	scene.revision.ui.dock_page.hide()
	var text: String = entry(&"sunlit-debrief").text if concluded() else debrief_text()
	scene.revision.ui.show_story_page("HALCYON / FIRST EXPEDITION",text,"Return to operations" if concluded() or not can_debrief() else "Submit expedition debrief",_submit_debrief,&"SubmitSunlitDebrief",_back_to_dock)
func debrief_text() -> String:
	if not scene.research.is_completed(SunlitShallowsData.BUOY): return "Okafor: We still need Lantern-1's buoy recording. Keep to the shallows and search near Twin Spires.\n\n"+guidance()
	var response: String = scene.bloom.response_text() if scene.story.resolved(LightBloomEncounter.ENCOUNTER) else "Crane: The light bloom still needs a deliberate study. A scan or a bottled specimen will suffice."
	return entry(&"sunlit-buoy-recovered").text+"\n\n"+response+"\n\n"+guidance()
func _submit_debrief() -> void:
	if can_debrief():
		if debrief(scene.station)!=OK:
			scene.revision.ui.add_story_notice("Debrief not saved. Your evidence is retained; retry after checkpoint recovery.")
			return
		show_conclusion()
	else: _back_to_dock()
func show_conclusion() -> void:
	scene.revision.ui.show_story_page("THE SUNLIT SHALLOWS / CHAPTER COMPLETE",entry(&"sunlit-debrief").text+"\n\n"+scene.bloom.response_text(),"Return to operations",_back_to_dock,&"FinishSunlit",_back_to_dock)
func _back_to_dock() -> void:
	scene.revision.ui.radio_page.hide()
	scene.revision.ui.show_dock()
func entries() -> Array[NarrativeEntry]:
	var result: Array[NarrativeEntry] = [entry(&"sunlit-arrival")]
	if state()!="available": result.append(entry(&"sunlit-orders"))
	if scene.story.resolved(LightBloomEncounter.ENCOUNTER):
		var bloom_entry: NarrativeEntry = NarrativeEntry.new()
		bloom_entry.stable_id = &"sunlit-bloom-observation"
		bloom_entry.title = "Light bloom · field decision"
		bloom_entry.text = scene.bloom.response_text()
		result.append(bloom_entry)
	if scene.research.is_completed(SunlitShallowsData.BUOY): result.append(entry(&"sunlit-buoy-recovered"))
	if concluded(): result.append(entry(&"sunlit-debrief"))
	return result
func log_text() -> String:
	var parts: PackedStringArray = []
	for record: NarrativeEntry in entries(): parts.append(record.title+"\n"+record.text)
	return "\n\n".join(parts)
func guidance() -> String:
	if concluded(): return "CHAPTER COMPLETE · Mara's message is archived · Twilight Shelf awaits a future expedition"
	if not scene.story.resolved(LightBloomEncounter.ENCOUNTER): return "Study the light bloom east of Halcyon · scan unharmed or bottle a specimen"
	if not scene.research.is_completed(SunlitShallowsData.BUOY): return "Find Lantern-1's buoy near Twin Spires · sonar, approach, Interact to recover"
	return "Bring Mara's recording home · return west through the upper passage and dock at Halcyon"
func _scan_completed(id: StringName) -> void:
	if active and id==SunlitShallowsData.BUOY:
		scene.revision.ui.notifications.enqueue("sunlit-buoy-recovered",entry(&"sunlit-buoy-recovered").text,"Wick / Mara’s buoy")
	_refresh()
func _choice_applied(id: StringName,_encounter: StringName) -> void:
	if active:
		scene.narrative._evidence_event(id)
	_refresh()
func _refresh() -> void:
	if buoy==null: return
	buoy.recovered = scene.research.is_completed(SunlitShallowsData.BUOY)
	buoy.queue_redraw()
	if not active: return
	scene.exploration_map.canvas.has_report = not buoy.recovered
	scene.exploration_map.canvas.reported_position = Vector2(3500,620)
	scene.exploration_map.canvas.queue_redraw()

func can_offer_prototype() -> bool:
	if OS.get_cmdline_user_args().has("--development"): return true
	if scene.saves==null or not scene.saves.has_checkpoint(): return false
	for id: String in scene.missions.snapshot():
		if id!=String(SunlitShallowsData.MISSION) and scene.missions.snapshot()[id].state!="available": return true
	return state()=="available"

func close_buoy_message() -> void:
	scene.revision.ui.notifications.collapse()
func _before_scan_completion(id: StringName) -> Error:
	if id!=SunlitShallowsData.BUOY:
		return _previous_scan_gate.call(id) if _previous_scan_gate.is_valid() else OK
	if scene.saves==null or not scene.submarine.scanner.eligible(id): return ERR_UNAVAILABLE
	var proposed: Array[StringName] = scene.research.completed_ids()
	proposed.append(id)
	return scene.saves.commit_research_checkpoint(proposed) if active else scene.saves.commit_progress(&"research",proposed)

func can_review_buoy() -> bool:
	return active and scene.research.is_completed(SunlitShallowsData.BUOY) and scene.submarine.global_position.distance_to(buoy.global_position)<=180.0
func read_buoy() -> Error:
	if not can_review_buoy() or scene.revision.ui.modal(): return ERR_UNAVAILABLE
	scene.revision.ui.notifications.replay("sunlit-buoy-recovered",entry(&"sunlit-buoy-recovered").text,"Wick / Mara’s buoy")
	return OK
