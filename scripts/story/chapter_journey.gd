class_name ChapterJourney
extends Node
## Scene-owned explicit transfers; existing mission/checkpoint/resource APIs own state.
const PRESSURE_FIT: ExpeditionPressureFit = preload("res://resources/story/twilight_pressure_fit.tres")
var scene: ShelfPrototype
var habitat: TwilightHabitat
var layout: TwilightShelfLayout
var state: Dictionary = ExpeditionJourneyState.fresh()
signal camera_settled
var transitioning: bool = false
var _settle_frames: int = 0
var _settle_world_visible: bool = true
var _prompt_open: bool = false
var _pause_title: String
func setup(game: ShelfPrototype) -> void:
	scene = game
	set_physics_process(false)
	var title: Label = scene.route_menu.find_child("Title",true,false) as Label
	_pause_title = title.text if title!=null else "EXPEDITION / PAUSED"
	assert(PRESSURE_FIT.is_valid())
	layout = TwilightShelfLayout.new()
	scene.region.add_child(layout)
	layout.configure(scene.chapter.dressing.rocks._paint)
	habitat = TwilightHabitat.new()
	add_child(habitat)
	habitat.setup(scene,layout)
	state = scene.saves._state.journey.duplicate(true)
	scene.expedition_log.finish_available = can_finish
	scene.expedition_log.finish_requested.connect(offer_finish)
	scene.revision.ui.show_title()
func snapshot() -> Dictionary:
	return state.duplicate(true)
func active() -> bool:
	return state.phase=="twilight"
func at_station() -> bool:
	return state.phase=="refit"
func near_tether() -> bool:
	return active() and scene.submarine.global_position.distance_to(TwilightShelfLayout.SPAWN)<=180
func can_finish() -> bool:
	return scene.chapter.active and not scene.chapter.concluded() and scene.chapter.state() in ["accepted","completed"] \
		and scene.research.is_completed(SunlitShallowsData.BUOY) and scene.story.resolved(LightBloomEncounter.ENCOUNTER)
func _show(title: String,body: String,action: String,callback: Callable,id: StringName) -> void:
	if transitioning: return
	scene.submarine.set_simulation_enabled(false)
	scene.submarine.velocity = Vector2.ZERO
	scene.expedition_log.hide()
	scene.revision.ui.notifications.collapse()
	_prompt_open = true
	scene.revision.ui.show_story_page(title,body,action,callback,id,_dismiss)
func _dismiss() -> void:
	_prompt_open = false
	scene.revision.ui.radio_page.hide()
	if at_station(): show_station()
	else: scene.resume_route()
func offer_finish() -> void:
	if not can_finish(): return
	_show("MARA'S RECORDING / EXPEDITION SECURED","The recording is safely aboard. Return directly to Halcyon for a debrief, or remain to explore. Your observations and light-bloom decision are preserved.","Finish chapter",_finish,&"FinishChapterAtBuoy")
	var back: Button = scene.revision.ui.find_child("StoryBack",true,false) as Button
	back.text = "Keep exploring"
func _finish() -> void:
	if transitioning: return
	var result: Error = scene.saves.finish_sunlit_return()
	if result!=OK:
		scene.revision.ui.add_story_notice("Return not saved. Evidence retained; retry after checkpoint recovery.")
		return
	await settle_camera()
	_prompt_open = false
	scene.chapter.show_conclusion()
func offer_deploy() -> void:
	if not scene.chapter.concluded(): return
	_show("THE TWILIGHT SHELF / DEEP DEPLOYMENT","Lantern-2 will be serviced and commissioned with a 1,000 m baseline pressure fit before deployment at 350 m. Existing research bonuses carry over. A nearby ascent tether provides return and refit access. Explore the west and east passages.\n\nThis exploration build includes historic wreck scenery, deep-water wildlife and erupting hydrothermal vents. Wait for a quiet window or pass around the hot jets. The wreck investigation and sentinel story encounter are not yet available.","Begin deep expedition",deploy,&"BeginTwilight")
func deploy() -> void:
	if not scene.chapter.concluded(): return
	await _transfer("twilight",not state.commissioned)
func offer_return() -> void:
	if not near_tether(): return
	_show("ASCENT TETHER / HALCYON TRANSFER","Return to Halcyon for repair, supplies and research refitting. Resume from this deployment pocket afterward; expedition records remain intact.","Return to Halcyon",return_to_station,&"ReturnHalcyon")
	(scene.revision.ui.find_child("StoryBack",true,false) as Button).text = "Stay here"
func return_to_station() -> void:
	if not near_tether(): return
	await _transfer("refit",true)
func resume_expedition() -> void:
	if not at_station(): return
	await _transfer("twilight",false)
func _transfer(phase: String,restock: bool) -> void:
	if transitioning: return
	var result: Error = scene.saves.transfer_chapter(phase,restock)
	if result!=OK:
		scene.revision.ui.add_story_notice("Transfer not saved; current expedition preserved. Retry after recovery.")
		return
	await settle_camera()
	_prompt_open = false
	scene.revision.ui.radio_page.hide()
	scene.revision.ui.dock_page.hide()
	scene.revision.ui.title_page.hide()
	if at_station(): show_station()
	else: scene.resume_route()
func show_station() -> void:
	scene.station.interact(scene.submarine)
	scene.revision.docking_report = "HALCYON TRANSFER · Supplies serviced · Expedition records preserved"
	scene.revision.ui.show_dock()
func prepare(value: Dictionary) -> void:
	state = value.duplicate(true)
	scene.exploration_map.presentation_name = "TWILIGHT SHELF" if active() else "CONTINENTAL SHELF"
	scene.chapter._activate(not active() and state.phase!="prototype")
	layout.set_enabled(active())
	habitat.set_enabled(active())
	scene.chapter.dressing.set_legacy_hidden(active() or scene.chapter.active)
	if not active():
		scene.exploration_map.canvas.chart_caption = ""
		scene.exploration_map.canvas.public_anchor = Vector2.INF
	var title: Label = scene.route_menu.find_child("Title",true,false) as Label
	if title!=null: title.text = "TWILIGHT SHELF / PAUSED" if active() else _pause_title
	if active():
		(scene.route_menu.get_node("%Brief") as Label).text = "Explore the west and east passages. Return to the ascent tether for Halcyon services and refitting. The wreck investigation and sentinel encounter will follow in a later release."
		(scene.hud.identity_container().get_node("Vessel") as Label).text = "LANTERN-2"
		scene.region.spawn.position = TwilightShelfLayout.SPAWN
		scene.region.camera_bounds = TwilightShelfLayout.CAMERA
		scene.region.configure_camera(scene.submarine.get_node("Camera2D") as Camera2D)
		scene.missions.progress_filter = func(_id: StringName) -> bool: return false
		scene.narrative.entries_provider = entries
		scene.narrative.conclusion_provider = func() -> bool: return false
		scene.narrative.debrief_ready_provider = func() -> bool: return false
		scene.narrative.guidance_provider = func() -> String: return "Explore the west and east passages · Return to the ascent tether for Halcyon refitting"
	refresh()
func refresh() -> void:
	if active():
		scene.exploration_map.presentation_bounds = Rect2(TwilightShelfLayout.CAMERA)
		scene.exploration_map.canvas.has_report = false
		scene.exploration_map.canvas.survey_enabled = false
		scene.exploration_map.canvas.chart_caption = "TWILIGHT SHELF / PUBLIC EXTENT"
		scene.exploration_map.canvas.public_anchor = TwilightShelfLayout.SPAWN
		(scene.exploration_map.find_child("Legend",true,false) as Label).text = "▲ YOU / vessel position\n◇ ASCENT TETHER / Halcyon access\n— PUBLIC survey boundary"
		scene.exploration_map.refresh()
	if scene.mission_tracker!=null: scene.mission_tracker.refresh()
func continue_from_title() -> void:
	if transitioning or scene.saves.continue_expedition()!=OK: return
	await settle_camera()
	scene.revision.ui.title_page.hide()
	if at_station(): show_station()
	else: scene.resume_route()

func entries() -> Array[NarrativeEntry]:
	var result: Array[NarrativeEntry] = scene.chapter.entries()
	var entry: NarrativeEntry = NarrativeEntry.new()
	entry.stable_id = &"twilight-deployment"
	entry.title = "Twilight Shelf / deployment"
	entry.text = "Lantern-2 deployed at 350 m with a commissioned pressure fit. Explore either the western wreck passage or eastern cable passage. Both connect through the lower shelf. The ascent tether returns to Halcyon for services and refitting. The full wreck investigation and sentinel encounter are not available in this exploration preview."
	result.append(entry)
	return result

func settle_camera() -> void:
	# The wait belongs to this node, so freeing a region cannot resume a dead coroutine.
	if not transitioning:
		transitioning = true
		_settle_frames = 2
		var world: Node2D = scene.get_node("WorldRoot") as Node2D
		_settle_world_visible = world.visible
		world.hide()
		set_physics_process(true)
	await camera_settled

func _physics_process(_delta: float) -> void:
	if not transitioning or scene.is_queued_for_deletion():
		set_physics_process(false)
		return
	_settle_frames -= 1
	if _settle_frames>0: return
	set_physics_process(false)
	var camera: Camera2D = scene.submarine.get_node("Camera2D") as Camera2D
	camera.reset_physics_interpolation()
	camera.reset_smoothing()
	camera.force_update_scroll()
	(scene.get_node("WorldRoot") as Node2D).visible = _settle_world_visible
	transitioning = false
	camera_settled.emit()
