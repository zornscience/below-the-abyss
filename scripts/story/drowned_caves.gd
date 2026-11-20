class_name DrownedCaves
extends Node
## Canonical Zone 3 adapter. Uses the shared scanner, StoryState and checkpoint.
var scene: ShelfPrototype
var journey: ChapterJourney
var layout: DrownedCavesLayout
var enabled: bool = false
var _previous_scan_gate: Callable
var _echoes: Array[SonarRevealTarget] = []
var _pattern_step: int = 0
var _mistakes: int = 0
var _guide_announced: bool = false
var _entry_announced: bool = false
const INTERACT_RADIUS: float = 310.0
const SIGNALS: Array[String] = ["Hold the light steady", "Send two short pulses", "Send one sustained pulse"]

func setup(game: ShelfPrototype, owner_journey: ChapterJourney) -> void:
	scene = game
	journey = owner_journey
	layout = DrownedCavesLayout.new()
	scene.region.add_child(layout)
	layout.setup(scene.chapter.dressing.rocks._paint)
	for item: Dictionary in DrownedCavesData.RECORDS:
		var echo: SonarRevealTarget = preload("res://scenes/props/sonar_reveal_target.tscn").instantiate() as SonarRevealTarget
		echo.name = String(item.id)+"Echo"
		echo.target_id = StringName(item.id+"-echo")
		echo.caption = item.title
		echo.position = item.at
		echo.revealed_for_ping.connect(func(_event: StringName) -> void: (echo.get_node("Caption") as Label).hide())
		layout.add_child(echo)
		(echo.get_node("Caption") as Label).hide()
		var bus: AcousticBus = scene.get_node("AcousticBus") as AcousticBus
		var bind_result: Error = echo.bind_bus(bus)
		var listen_result: Error = scene.submarine.sonar.listen_to(echo)
		var discover_result: Error = scene.discoveries.connect_sonar_target(echo)
		if bind_result!=OK or listen_result!=OK or discover_result!=OK:
			push_error("Cave echo registration failed for "+String(item.id))
		_echoes.append(echo)
	_previous_scan_gate = scene.research.completion_gate
	scene.research.completion_gate = _scan_gate
	scene.research.scan_completed.connect(_scanned)
	scene.story.choice_applied.connect(_choice_applied)
	scene.story.flag_changed.connect(_flag_changed)
	scene.saves.checkpoint_restored.connect(_checkpoint_restored)
	scene.settings.settings_changed.connect(_preferences)
	set_enabled(false)

func set_enabled(value: bool) -> void:
	enabled = value
	layout.set_enabled(value)
	for item: Dictionary in DrownedCavesData.RECORDS:
		var subject: ScientificScanTarget = scene.region.get_node(String(item.id)) as ScientificScanTarget
		subject.scan_enabled = value
	for echo: SonarRevealTarget in _echoes: echo.receiver.enabled = value
	layout.refresh_story(scene.story)
	if not value:
		_pattern_step = 0
		_guide_announced = false
		_entry_announced = false

func _preferences() -> void:
	if layout==null: return
	layout.crystal.color = Color(0.65,0.94,0.98) if scene.settings.snapshot().accessibility.high_contrast else Color(0.45,0.88,0.91,0.78)

func _checkpoint_restored() -> void:
	_pattern_step = 0
	_mistakes = 0
	_guide_announced = false
	_entry_announced = false
	layout.refresh_story(scene.story)

func _scan_gate(id: StringName) -> Error:
	if not DrownedCavesData.knows(id):
		return _previous_scan_gate.call(id) if _previous_scan_gate.is_valid() else OK
	if not enabled or not scene.submarine.scanner._in_range(id): return ERR_UNAVAILABLE
	var proposed: Array[StringName] = scene.research.completed_ids()
	proposed.append(id)
	return scene.saves.commit_research_checkpoint(proposed)

func _scanned(id: StringName) -> void:
	if not enabled or not DrownedCavesData.knows(id): return
	var item: Dictionary = DrownedCavesData.record(id)
	var speaker: String = "Mara" if String(id).contains("mara") else ("Okafor" if id==&"caves-human-handprints" else "Wick")
	scene.revision.ui.notifications.enqueue(String(id),item.text,speaker)
	journey.refresh()

func _flag_changed(id: StringName) -> void:
	if id!=DrownedCavesData.UNDERSTOOD or not enabled: return
	scene.revision.ui.notifications.enqueue("caves-translation","Wick: The recurring phrases are WAIT, ANSWER, REMAIN. This is partial translation, not full Vael speech.","Wick")
	journey.refresh()

func _choice_applied(_id: StringName,encounter: StringName) -> void:
	if encounter!=DrownedCavesData.ENCOUNTER: return
	layout.refresh_story(scene.story)
	scene.upgrades.reapply()
	if enabled:
		_pause()
		_show_result()
	journey.refresh()

func near_shrine() -> bool:
	return enabled and scene.submarine.global_position.distance_to(DrownedCavesData.SHRINE)<=INTERACT_RADIUS
func near_exit() -> bool:
	return enabled and scene.submarine.global_position.distance_to(DrownedCavesData.EXIT)<=INTERACT_RADIUS
func unsafe_at(at: Vector2) -> bool:
	return enabled and layout.silt_current(at)!=Vector2.ZERO

func interact() -> bool:
	if near_shrine():
		_pause()
		if scene.story.resolved(DrownedCavesData.ENCOUNTER):
			_show_result()
		elif not DrownedCavesData.evidence_complete(scene.research):
			var missing: Array[String] = []
			for id: StringName in DrownedCavesData.REQUIRED:
				if not scene.research.is_completed(id): missing.append(DrownedCavesData.record(id).title)
			if not scene.research.is_completed(&"caves-memory-shrine"): missing.append("The memory shrine (scan)")
			scene.revision.ui.show_story_page("THE ARCHIVE / EVIDENCE INCOMPLETE",
				"Wick: The archive does not answer yet. Record these sites before trying the light language:\n\n"+ "\n".join(missing),
				"Return to exploration",_leave,&"CaveMissingEvidence",_leave)
		elif not scene.story.has_flag(DrownedCavesData.UNDERSTOOD):
			_pattern_step = 0
			_show_pattern()
		else:
			_show_choice()
		return true
	if near_exit():
		journey.offer_caves_return()
		return true
	return false

func _pause() -> void:
	scene.submarine.velocity = Vector2.ZERO
	scene.submarine.set_simulation_enabled(false)
	scene.revision.ui.notifications.collapse()
func _leave() -> void:
	scene.revision.ui.radio_page.hide()
	scene.resume_route()

func _show_pattern() -> void:
	var explanation: String = "Wick: The two accounts agree on loss, not blame. The glyphs carry three words: WAIT, ANSWER, REMAIN. The handprint wall shows an open, motionless hand, then a pair of strokes, then a long arc.\n\n"
	if _mistakes>=2:
		explanation += "Hint: first hold your light steady, then two short pulses, then one sustained pulse.\n\n"
	explanation += "Signal %d of 3. Choose a lamp response. Incorrect patterns can be tried again; no equipment or attack is required." % (_pattern_step+1)
	scene.revision.ui.show_story_page("THE ARCHIVE / LIGHT EXCHANGE",explanation,SIGNALS[0],_pattern_input.bind(0),&"CaveSignalStill",_leave)
	scene.revision.ui.add_story_option(SIGNALS[1],_pattern_input.bind(1),&"CaveSignalTwo")
	scene.revision.ui.add_story_option(SIGNALS[2],_pattern_input.bind(2),&"CaveSignalLong")

func _pattern_input(option: int) -> void:
	if not enabled or not near_shrine(): return
	if option!=_pattern_step:
		_mistakes += 1
		_pattern_step = 0
		_show_pattern()
		return
	_pattern_step += 1
	if _pattern_step<3:
		_show_pattern()
		return
	if not scene.story.has_flag(DrownedCavesData.UNDERSTOOD):
		var saved: Error = scene.story.set_flag(DrownedCavesData.UNDERSTOOD)
		if saved!=OK:
			_pattern_step = 0
			scene.revision.ui.show_story_page("ARCHIVE / SIGNAL NOT RECORDED",
				"The reply was recognized, but the checkpoint could not save it. No translation was granted. Retry when storage is available.",
				"Retry light exchange",_show_pattern,&"RetryCavePattern",_leave)
			return
	_show_choice()

func _show_choice() -> void:
	scene.revision.ui.show_story_page("THE MEMORY / WHO OWNS A RECORD?",
		"The memory has recognized your answer. The archive belongs to neither the Institute nor Tethys.\n\n"
		+"Wick: This is a living memory. A recovered crystal can calibrate long-range sonar, but removing it destroys a part of the archive here.\n\n"
		+"Okafor: An object can be evidence without becoming our property.\n\n"
		+"Crane: Bring back what can be safely preserved.\n\n"
		+"Leave it and its testimony remains for those who made it. Remove it and gain +175 sonar range; the cradle and its side alcove will collapse. Both choices are permanent.",
		"Leave the living archive where it rests",_decide.bind(DrownedCavesData.LEAVE),&"LeaveCaveCrystal",_leave)
	scene.revision.ui.add_story_option("Remove the archive for sonar calibration",_decide.bind(DrownedCavesData.TAKE),&"TakeCaveCrystal")

func _decide(id: StringName) -> void:
	if not enabled or not near_shrine() or not scene.story.has_flag(DrownedCavesData.UNDERSTOOD): return
	var result: Error = scene.story.apply_choice(id)
	if result!=OK:
		scene.revision.ui.show_story_page("CHOICE NOT SAVED","The archive is unchanged. Your decision was not recorded. Return to the choice after recovering the checkpoint.",
			"Retry decision",_show_choice,&"RetryCaveChoice",_leave)

func _show_result() -> void:
	var id: StringName = DrownedCavesData.TAKE if scene.story.has_decision(DrownedCavesData.TAKE) else DrownedCavesData.LEAVE
	scene.revision.ui.show_story_page("THE DROWNED CAVES / MEMORY DECISION",
		scene.story.definition(id).response_text+"\n\nWick: The Choir remains unexplained. The next bearing leads toward the Furnace Vents. Return to the ascent route to archive this chapter.",
		"Return to piloting",_leave,&"FinishCaveDecision",_leave)

func concluded() -> bool:
	return scene.story.resolved(DrownedCavesData.ENCOUNTER)
func guidance() -> String:
	if concluded(): return "✓ Drowned Caves archived · return to the ascent route for Halcyon"
	if not scene.research.is_completed(&"caves-human-handprints"): return "◇ Investigate the human handprint wall"
	if not scene.research.is_completed(&"caves-vael-account"): return "◇ Record the other testimony"
	if not scene.research.is_completed(&"caves-mara-log-four"): return "◇ Recover Mara's fourth log"
	if not scene.research.is_completed(&"caves-memory-shrine"): return "◇ Scan the memory shrine"
	if not scene.story.has_flag(DrownedCavesData.UNDERSTOOD): return "◇ Answer the shrine's three light signals"
	return "◇ Decide whether to preserve or collect the archive"

func entries() -> Array[NarrativeEntry]:
	var result: Array[NarrativeEntry] = []
	var opening: NarrativeEntry = NarrativeEntry.new()
	opening.stable_id = &"caves-expedition-orders"
	opening.title = "Drowned Caves / first contact"
	opening.text = "Flooded limestone caverns, 1,000 to 2,000 m. Investigate the handprints, another account, Mara's notes and a living archive. The missing pilot is not here. Watch the silt current and your oxygen reserves. Return to the entrance if you need a Halcyon refit."
	result.append(opening)
	for item: Dictionary in DrownedCavesData.RECORDS:
		if not scene.research.is_completed(StringName(item.id)): continue
		var entry: NarrativeEntry = NarrativeEntry.new()
		entry.stable_id = StringName(item.id)
		entry.title = item.title
		entry.text = item.text
		result.append(entry)
	if scene.story.has_flag(DrownedCavesData.UNDERSTOOD):
		var translated: NarrativeEntry = NarrativeEntry.new()
		translated.stable_id = DrownedCavesData.UNDERSTOOD
		translated.title = "Light language / partial translation"
		translated.text = "WAIT. ANSWER. REMAIN. Wick is confident in those words, not in the meaning of the complete account."
		result.append(translated)
	if concluded():
		var ending: NarrativeEntry = NarrativeEntry.new()
		ending.stable_id = &"caves-archive-decision"
		ending.title = "The archive / decision"
		ending.text = scene.story.definition(DrownedCavesData.TAKE if scene.story.has_decision(DrownedCavesData.TAKE) else DrownedCavesData.LEAVE).response_text
		result.append(ending)
	return result

func _physics_process(delta: float) -> void:
	if not enabled or not scene.submarine.is_physics_processing(): return
	var at: Vector2 = scene.submarine.global_position
	var flow: Vector2 = layout.silt_current(at)
	if flow!=Vector2.ZERO:
		scene.submarine.velocity += flow*delta
	if not _entry_announced:
		_entry_announced = true
		scene.revision.ui.notifications.enqueue("caves-arrival",
			"Wick: 1,120 metres. The old coastline is now rock overhead. The handprint wall is east of our position. The sonar chart cannot see through the galleries. Watch the oxygen reserve.","Wick")
	if layout.guide.visible and not _guide_announced and at.distance_to(layout.guide.position)<1050:
		_guide_announced = true
		scene.revision.ui.notifications.enqueue("caves-sentinel-guide",
			"Wick: That is the animal we released at the drift net. It waits beside the gentler current. It will not follow a torpedo; dim your lights and observe its path.","Wick")
