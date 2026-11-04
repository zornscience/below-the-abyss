extends "res://tests/fixtures/drive_twilight_expedition.gd"
## Optional circuit plus the unchanged complete expedition; no teleports or direct rewards.
func _after_deployment() -> bool:
	var started: float = _clock.seconds
	await _move(Vector2(31950,1400))
	await _move(Vector2(31950,2300))
	await _capture("inner-chimney")
	await _survey_record(&"twilight-cargo-timber")
	await _move(Vector2(31950,2300))
	await _survey_record(&"twilight-ballast-pocket")
	await _capture("cargo-pocket")
	await _move(Vector2(33450,2300))
	await _move(Vector2(33450,1400))
	await _survey_record(&"twilight-line-anchor")
	await _capture("anchor-clue")
	await _view_survey_record()
	await _move(Vector2(35800,1400))
	await _move(Vector2(35800,2850))
	await _move(Vector2(36500,2850))
	await _survey_record(&"twilight-thermal-crust")
	await _capture("thermal-observation")
	assert(not TwilightShelfData.ready(_scene.research,_scene.story))
	assert(not _scene.story.resolved(TwilightShelfData.ENCOUNTER))
	await _move(Vector2(37800,2900))
	await _frames(5)
	assert(_scene.journey.expedition.glimpse_seen)
	await _capture("first-living-glimpse")
	await _move(Vector2(37800,2850))
	await _move(Vector2(35800,2850))
	await _move(Vector2(35800,1400))
	await _move(TwilightShelfLayout.SPAWN)
	print("TWILIGHT_SURVEY_INPUT_PASS input=",("keyboard" if _keyboard else "controller")," optional_simulation_seconds=",_clock.seconds-started," optional_records=4 unchanged_required_evidence=true")
	return await super._after_deployment()

func _survey_record(id: StringName) -> void:
	var target: Vector2 = _scene.research.definition(id).position
	# Keep x aligned in blind recesses rather than approaching through their closed wall.
	await _move(target-Vector2(0,80),true)
	await _interact()
	await _frames(340)
	assert(_scene.research.is_completed(id),"Intentional scan did not complete: "+String(id))
	assert(String(id) in _scene.saves._state.progress.research)
	await _capture(String(id))

func _view_survey_record() -> void:
	await _tap(JOY_BUTTON_BACK)
	await _activate(_scene.exploration_map.get_node("%OpenResearch") as Control)
	var selected: Control
	for child: Node in _scene.research_log.get_node("%ResearchEntries").get_children():
		if child is Button and child.text==_scene.research.definition(&"twilight-cargo-timber").title: selected = child
	assert(selected!=null)
	await _activate(selected)
	await super._capture("illustrated-research-record")
	await _activate(_scene.research_log.get_node("%CloseResearch") as Control)
	await _tap(JOY_BUTTON_BACK)

func _capture(name: String) -> void:
	await super._capture(name)
	if name=="twilight-continue-no-replay":
		for id: StringName in TwilightShelfData.OPTIONAL_SURVEY: assert(_scene.research.is_completed(id))
		await _view_survey_record()
