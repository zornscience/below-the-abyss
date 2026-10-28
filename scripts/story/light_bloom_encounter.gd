class_name LightBloomEncounter
extends Node
## Narrow canonical-character adapter. It reuses Interact, sonar eligibility and timed scanning.
const ENCOUNTER: StringName = &"zone1-light-bloom"
const SCAN: StringName = &"zone1-light-bloom-scan"
const OBSERVE: StringName = &"zone1-light-bloom-observe"
const COLLECT: StringName = &"zone1-light-bloom-collect"
const POI: StringName = &"zone1-light-bloom-habitat"
var scene: ShelfPrototype
var visual: LightBloomVisual
var panel: BloomChoicePanel
var target: ScientificScanTarget
var _pending_scan: bool = false
var feedback: String = ""
func setup(owner_scene: ShelfPrototype) -> void:
	scene = owner_scene
	target = scene.region.get_node(String(SCAN)) as ScientificScanTarget
	target.hide()
	visual = LightBloomVisual.new()
	visual.position = target.position
	scene.region.add_child(visual)
	panel = BloomChoicePanel.new()
	add_child(panel)
	panel.setup(self)
	scene.research.completion_gate = _before_research_completion
	scene.story.choice_applied.connect(_choice_applied)
	scene.submarine.scanner.state_changed.connect(_scan_changed)
	scene.settings.settings_changed.connect(_comfort_changed)
	if scene.saves!=null: scene.saves.checkpoint_restored.connect(refresh_state)
	_comfort_changed()
	refresh_state()
func _process(delta: float) -> void:
	if scene!=null:
		visual.advance_arrival(delta,scene.submarine.global_position,scene.submarine.is_physics_processing())
func in_range() -> bool:
	return scene.submarine.global_position.distance_to(target.global_position)<=scene.research.definition(SCAN).radius
func identified() -> bool:
	return not scene.research.definition(SCAN).requires_sonar or scene.discoveries.state_of(POI)==DiscoveryRegistry.State.DISCOVERED
func modal() -> bool:
	return panel.visible_page()
func can_choose() -> bool:
	return scene.saves!=null and scene.saves.can_write() and in_range() and identified() and not scene.story.resolved(ENCOUNTER)
func interact() -> Error:
	if not scene.submarine.is_physics_processing() or not in_range() or modal(): return ERR_UNAVAILABLE
	var state: Dictionary = scene.submarine.scanner.snapshot()
	if state.active_id==SCAN:
		scene.submarine.scanner.request_scan()
		_pending_scan = false
		return OK
	feedback = ""
	if in_range() and not scene.research.definition(SCAN).requires_sonar and scene.discoveries.state_of(POI)!=DiscoveryRegistry.State.DISCOVERED:
		scene.discoveries.discover(POI,&"bloom/visual-acquisition")
	if state.active_id!=&"":
		feedback = "Finish or cancel the current scan before studying the bloom."
		return ERR_BUSY
	scene.submarine.velocity = Vector2.ZERO
	scene.submarine.set_simulation_enabled(false)
	if scene.story.resolved(ENCOUNTER): panel.show_response(response_text())
	else: panel.show_choice()
	return OK
func choose_observe() -> Error:
	if not modal() or not can_choose(): return ERR_UNAVAILABLE
	panel.hide_page()
	scene.resume_route()
	_pending_scan = true
	var result: Error = scene.submarine.scanner.request_scan(SCAN)
	if result!=OK:
		_pending_scan = false
		feedback = "The scan could not start. Identify the bloom with sonar and stay in range."
	return result
func choose_collect() -> Error:
	if not modal() or not can_choose() or scene.submarine.scanner.snapshot().active_id!=&"": return ERR_UNAVAILABLE
	return scene.story.apply_choice(COLLECT)
func _before_research_completion(id: StringName) -> Error:
	if id!=SCAN: return OK
	if not _pending_scan or not in_range() or not identified(): return ERR_UNAUTHORIZED
	# SaveCoordinator commits the research ID and story decision together, before either event.
	return scene.story.apply_choice(OBSERVE)
func _choice_applied(id: StringName, encounter: StringName) -> void:
	if encounter!=ENCOUNTER: return
	_pending_scan = false
	refresh_state(true)
	scene.submarine.velocity = Vector2.ZERO
	scene.submarine.set_simulation_enabled(false)
	panel.show_response(scene.story.definition(id).response_text)
func _scan_changed() -> void:
	if _pending_scan and scene.submarine.scanner.snapshot().active_id!=SCAN:
		_pending_scan = false
		if not scene.story.resolved(ENCOUNTER): feedback = String(scene.submarine.scanner.snapshot().text)
func refresh_state(animate: bool = false) -> void:
	var harvested: bool = scene.story.has_decision(COLLECT)
	var observed: bool = scene.story.has_decision(OBSERVE)
	target.scan_enabled = not harvested and not observed
	visual.set_outcome(harvested,observed,animate)
func response_text() -> String:
	var id: StringName = COLLECT if scene.story.has_decision(COLLECT) else OBSERVE
	return scene.story.definition(id).response_text
func leave() -> void:
	panel.hide_page()
	scene.resume_route()
func reset_session() -> void:
	_pending_scan = false
	panel.hide_page()
	refresh_state()
func prompt() -> String:
	var binding: String = scene.input_context.describe(&"interact").get_slice(" / ",0).replace("Controller ","")
	if not feedback.is_empty() and scene.submarine.scanner._feedback_seconds>0.0: return feedback
	if scene.story.resolved(ENCOUNTER): return binding+" · Review the light-bloom record"
	if not identified():
		var ping: String = scene.input_context.describe(&"sonar_ping").get_slice(" / ",0).replace("Controller ","")
		return ping+" · Identify the light bloom with sonar"
	return binding+" · Study the light bloom"
func _comfort_changed() -> void:
	var comfort: Dictionary = scene.settings.snapshot().accessibility
	visual.reduced_effects = comfort.reduced_motion or comfort.reduced_flashing
	if visual.reduced_effects: visual.reaction = 0.0
	visual.queue_redraw()
	panel.refresh_comfort()
