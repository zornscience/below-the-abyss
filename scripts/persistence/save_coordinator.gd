class_name SaveCoordinator
extends Node
## Scene-owned checkpoint coordinator. All domain stores use its optional write port.

signal status_changed
signal checkpoint_restored
var last_campaign_archive: String = ""
var status: String = "No expedition save loaded."
var store: ExpeditionStore = ExpeditionStore.new()
var _scene: ShelfPrototype
var _state: Dictionary = {}
var _busy: bool = false
var _ready_to_write: bool = false
var _has_checkpoint: bool = false


func _report(message: String, result: Error) -> Error:
	status = message
	status_changed.emit()
	return result


func setup(scene: ShelfPrototype, path: String) -> Error:
	_scene = scene
	scene.story.persistence_required = true
	scene.story.checkpoint_writer = Callable()
	store.path = path
	var document: Dictionary = store.load_checkpoint()
	if document.error == OK:
		_state = document.data
		if scene.story.restore(_state.story)!=OK: return _report("Conflicting story checkpoint; live progress and files preserved.",ERR_BUSY)
		_state.progress = ExpeditionSchema.merge_progress(_state.progress, progress_snapshot())
		_state.prototype.campaign.science = ResearchExperienceData.reconcile(_state.prototype.campaign.science,_state.progress.research)
		apply_progress(_state.progress)
		_has_checkpoint = true
	elif document.error == ERR_FILE_NOT_FOUND and not FileAccess.file_exists(path + ".bak"):
		# Reject unreadable legacy data on the first migration, not silently starting fresh.
		for legacy: Variant in [scene.discovery_store, scene.research_store, scene.upgrades.store, scene.missions.store]:
			if legacy.last_result != OK and (legacy.last_result != ERR_FILE_NOT_FOUND or FileAccess.file_exists(legacy.path + ".bak")):
				return _report("Legacy progress needs recovery before migration. Use its existing recovery page, then retry Save.", ERR_INVALID_DATA)
		_state = snapshot()
		if scene.extended_expedition:
			# A pre-checkpoint legacy profile can already have earned the old ending.
			var records: Dictionary = _state.progress.missions
			_state.legacy_conclusion = records["shelf-expedition"].state == "claimed" and records["shelf-calibration-study"].state == "claimed" and records[String(ShelfChapterData.OUTER)].state == "available" and records[String(ShelfChapterData.WRECK)].state == "available"
	else:
		return _report("Expedition file unavailable (%s). Preserved; use Recover expedition backup." % error_string(document.error), document.error)
	_ready_to_write = true
	_delegate_stores()
	return _report("Continue is available; checkpoint validated." if _has_checkpoint else "No expedition checkpoint yet. Begin exploration, then Save or use station services.", OK)


func _delegate_stores() -> void:
	_scene.story.checkpoint_writer = commit_story
	for legacy: Variant in [_scene.discovery_store, _scene.research_store, _scene.upgrades.store, _scene.missions.store]:
		legacy.checkpoint_writer = commit_progress
		legacy._report("Progress managed by expedition checkpoint; legacy files preserved.", OK)


func progress_snapshot() -> Dictionary:
	# JSON-shaped strings are canonical, not runtime instance IDs or Resources.
	return {"discoveries": _strings(_scene.discoveries.discovered_ids()), "research": _strings(_scene.research.completed_ids()),
		"upgrades": _strings(_scene.upgrades.installed_ids()), "missions": _scene.missions.snapshot()}


func _strings(ids: Array[StringName]) -> Array:
	var result: Array = []
	for id: StringName in ids:
		result.append(String(id))
	result.sort()
	return result


func _names(ids: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: String in ids:
		result.append(StringName(id))
	return result


func snapshot() -> Dictionary:
	var vessel: SubmarineController = _scene.submarine
	return {"format": "bta-expedition", "schema_version": ExpeditionSchema.VERSION, "region_id": ExpeditionJourneyState.region(journey_snapshot()), "journey":journey_snapshot(), "legacy_imported": true,
		"legacy_conclusion": bool(_state.get("legacy_conclusion",false)),
		"story": _scene.story.snapshot(),
		"prototype": prototype_snapshot(),
		"terrain": _scene.excavation.snapshot() if _scene.excavation != null else [],
		"player": {"position": [vessel.global_position.x, vessel.global_position.y], "rotation": wrapf(vessel.rotation, -PI, PI),
			"hull": vessel.hull_system.hull, "battery": vessel.resource_system.battery, "oxygen": vessel.resource_system.oxygen,
			"sonar_cooldown": vessel.sonar.cooldown_remaining()},
		"progress": progress_snapshot(), "route": {"stage": _scene.route_check.stage, "elapsed_seconds": _scene.route_check.elapsed_seconds}}


func has_checkpoint() -> bool:
	return _has_checkpoint


func position_clear(at: Vector2, orientation: float) -> bool:
	if not at.is_finite() or not is_finite(orientation) or not Rect2(_scene.region.camera_bounds).has_point(at):
		return false
	if _scene.chapter!=null and _scene.chapter.active and at.y<16.0: return false
	var vessel: SubmarineController = _scene.submarine
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = (vessel.get_node("CollisionShape2D") as CollisionShape2D).shape
	query.transform = Transform2D(orientation, at) * (_scene.submarine.get_node("CollisionShape2D") as CollisionShape2D).transform
	query.collision_mask = vessel.collision_mask
	query.exclude = [vessel.get_rid()]
	if _scene.excavation != null:
		for rock: DestructibleRock in _scene.excavation._rocks.values():
			query.exclude.append(rock.get_rid())
		var capsule: CapsuleShape2D = query.shape as CapsuleShape2D
		var footprint: PackedVector2Array = []
		for index: int in range(32):
			var angle: float = index * TAU / 32.0
			var point: Vector2 = Vector2.from_angle(angle) * capsule.radius / cos(PI/32.0)
			point.y += signf(point.y) * (capsule.height*0.5-capsule.radius)
			footprint.append(query.transform * point)
		for rock: DestructibleRock in _scene.excavation._rocks.values():
			if (rock.collision_layer & vessel.collision_mask)==0: continue
			for part: PackedVector2Array in rock.pieces:
				var polygon: PackedVector2Array = []
				for point: Vector2 in part: polygon.append(rock.to_global(point))
				if not Geometry2D.intersect_polygons(footprint, polygon).is_empty(): return false
	return vessel.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func safe_to_save() -> bool:
	return (_scene.journey==null or not _scene.journey.expedition.pending_loss) and _scene.submarine.hull_system.hull>0 and _scene.submarine.resource_system.oxygen>0 \
		and (_scene.journey==null or not _scene.journey.habitat.unsafe_at(_scene.submarine.global_position)) \
		and not _scene.submarine.is_physics_processing() and position_clear(_scene.submarine.global_position, _scene.submarine.rotation) \
		and _scene.submarine.damage_system.warning_state != SubmarineDamageSystem.WarningState.EXCEEDED \
		and _scene.predator.threat.phase not in [PredatorState.Phase.ALERT, PredatorState.Phase.PURSUE]


func _write(candidate: Dictionary, message: String, scientific_awards: Array[StringName] = []) -> Error:
	if _busy or not _ready_to_write:
		return _report("Save blocked; recover the existing checkpoint before writing.", ERR_BUSY)
	if _scene.journey!=null and _scene.journey.expedition.pending_loss and String(TwilightShelfData.LOST) not in candidate.story.decisions and "zone2-released-sentinel-lost" not in candidate.story.flags:
		return _report("Record the pending casualty before saving other progress.",ERR_BUSY)
	_busy = true
	var reconciled: Dictionary = StoryState.merge_snapshots(candidate.story,_state.story)
	if reconciled.error!=OK:
		_busy = false
		return _report("Conflicting story decisions; existing checkpoint preserved.",reconciled.error)
	candidate.story = reconciled.data
	candidate.journey.commissioned = candidate.journey.commissioned or _state.journey.commissioned
	candidate.progress = ExpeditionSchema.merge_progress(candidate.progress, _state.progress)
	candidate.prototype.campaign = CampaignData.merge_earned(candidate.prototype.campaign,_state.prototype.campaign)
	candidate.prototype.campaign.science = ResearchExperienceData.reconcile(candidate.prototype.campaign.science,candidate.progress.research,scientific_awards)
	var result: Error = store.write_checkpoint(candidate)
	if result == OK:
		_state = candidate.duplicate(true)
		_has_checkpoint = true
		if _scene.revision!=null and _scene.revision.campaign.science!=candidate.prototype.campaign.science:
			_scene.revision.campaign.science = candidate.prototype.campaign.science.duplicate(true)
			_scene.revision.research_changed.emit()
	_report(message if result == OK else "Not saved (%s). Files preserved; recover or inspect checkpoint." % error_string(result), result)
	_busy = false
	return result


func save_current() -> Error:
	if not _ready_to_write:
		var result: Error = setup(_scene, store.path)
		if result != OK:
			return result
	if not safe_to_save():
		return _report("Not saved: pause in clear terrain, outside pressure/thermal danger and predator alert/pursuit.", ERR_UNAVAILABLE)
	return _write(snapshot(), "Expedition saved: position, supplies and progress committed.")


func commit_progress(kind: StringName, proposed: Variant) -> Error:
	if _busy or not _ready_to_write:
		return ERR_BUSY
	var candidate: Dictionary = _state.duplicate(true)
	candidate.prototype = prototype_snapshot()
	candidate.story = _scene.story.snapshot()
	candidate.terrain = _scene.excavation.snapshot() if _scene.excavation != null else []
	candidate.progress = progress_snapshot()
	candidate.progress[String(kind)] = proposed.duplicate(true) if proposed is Dictionary else _strings(proposed)
	if not ExpeditionSchema.valid_progress(candidate.progress):
		return ERR_INVALID_DATA
	var twilight_claim: bool = kind==&"missions" and candidate.progress.missions.get(String(TwilightShelfData.MISSION),{}).get("state")=="claimed" and _state.progress.missions.get(String(TwilightShelfData.MISSION),{}).get("state")!="claimed"
	if twilight_claim:
		if _scene.journey==null or not _scene.journey.at_station() or _state.progress.missions.get(String(TwilightShelfData.MISSION),{}).get("state")!="completed" or not TwilightShelfData.ready(_scene.research,_scene.story): return ERR_UNAUTHORIZED
		if "twilight-expedition" not in candidate.prototype.campaign.awards: candidate.prototype.campaign.awards.append("twilight-expedition")
		if _scene.story.has_decision(TwilightShelfData.CAPTURE) and "twilight-specimen" not in candidate.prototype.campaign.awards: candidate.prototype.campaign.awards.append("twilight-specimen")
	# Docked domain operations are safe checkpoints. Else only permanent records advance.
	if _scene.station_menu.visible and safe_to_save():
		var current: Dictionary = snapshot()
		candidate.player = current.player
		candidate.route = current.route
	var result: Error = _write(candidate, "Progress committed; expedition checkpoint retained." if not _scene.station_menu.visible else "Station checkpoint saved with permanent progress.")
	if result==OK and twilight_claim: _scene.revision.restore(_state.prototype)
	return result


func apply_progress(progress: Dictionary) -> void:
	if _scene.extended_expedition and progress.missions.size() == 2:
		progress.missions = ShelfChapterData.upgrade_missions(progress.missions)
	_scene.discoveries.restore_discoveries(_names(progress.discoveries))
	_scene.research.restore_completed(_names(progress.research))
	_scene.upgrades.restore_installed(_names(progress.upgrades))
	var projected: Dictionary = _scene.missions.snapshot()
	for id: String in projected:
		if progress.missions.has(id): projected[id] = progress.missions[id].duplicate(true)
	_scene.missions.restore_records(projected)


func continue_expedition() -> Error:
	if _busy or not _has_checkpoint or _scene.submarine.sonar.is_mutating():
		return _report("No validated checkpoint available to continue.", ERR_UNAVAILABLE)
	var validated: Dictionary = ExpeditionSchema.decode(_state)
	if validated.error != OK:
		return _report("Checkpoint validation failed; vessel unchanged.", validated.error)
	var saved: Dictionary = validated.data
	if _scene.excavation != null and _scene.excavation.restore(saved.terrain) != OK:
		return _report("Terrain checkpoint rejected; vessel unchanged.", ERR_INVALID_DATA)
	var layout: SunlitRegionLayout = _scene.region.get_node_or_null("SunlitRegionLayout") as SunlitRegionLayout
	if layout!=null:
		layout.preserve_archived_opening(_scene.excavation,saved.progress.discoveries)
		saved.terrain = _scene.excavation.snapshot()
		_state.terrain = saved.terrain.duplicate(true)
	var previous_journey: Dictionary = journey_snapshot()
	if _scene.journey!=null: _scene.journey.prepare(saved.journey)
	var at: Vector2 = Vector2(saved.player.position[0], saved.player.position[1])
	var angle: float = saved.player.rotation
	var relocated: bool = not position_clear(at, angle)
	if relocated:
		at = _scene.region.spawn.global_position
		angle = 0.0
		if not position_clear(at, angle):
			if _scene.journey!=null: _scene.journey.prepare(previous_journey)
			return _report("No clear station fallback; load cancelled without changing the vessel.", ERR_UNAVAILABLE)
	_busy = true
	# This coordinator never issues gameplay discovery, scan, claim or ping commands.
	_scene.submarine.set_simulation_enabled(false)
	_scene.station.end_interaction()
	_scene.station_menu.hide()
	if _scene.revision!=null:
		_scene.revision.ui.dock_page.hide()
		_scene.revision.ui.radio_page.hide()
	if _scene.bloom!=null: _scene.bloom.reset_session()
	_scene.submarine.scanner.reset_session()
	if _scene.torpedoes != null:
		_scene.torpedoes.reset_session()
	_scene.submarine.sonar.reset_session()
	_scene.submarine.passive.reset_session()
	_scene.ambient.reset_session()
	_scene.creature.reset_session()
	_scene.predator.reset_session()
	if _scene.extension != null:
		for grazer: AcousticCreature in _scene.extension.wildlife: grazer.reset_session()
	if _scene.gameplay_audio != null:
		_scene.gameplay_audio.reset_session()
	_scene.story.restore(saved.story)
	apply_progress(saved.progress)
	if _scene.revision != null: _scene.revision.restore(saved.prototype)
	var vessel: SubmarineController = _scene.submarine
	vessel.global_position = at
	vessel.rotation = angle
	vessel.velocity = Vector2.ZERO
	vessel.resource_system.restore_snapshot(saved.player.battery, saved.player.oxygen)
	vessel.hull_system.restore_snapshot(saved.player.hull)
	vessel.damage_system.configure(vessel.damage_system.configuration)
	_scene.upgrades.reapply()
	vessel.damage_system.advance(0.0, _scene.region.depth_at_world(at), vessel.hull_system)
	vessel.sonar.restore_cooldown(saved.player.sonar_cooldown)
	_scene.route_check.stage = GrayboxRouteCheck.Stage.AT_BASE if relocated else int(saved.route.stage) as GrayboxRouteCheck.Stage
	_scene.route_check.synchronize_base_state(_scene.region.base_zone.contains_world_position(at))
	_scene.route_check.elapsed_seconds = 0.0 if relocated else saved.route.elapsed_seconds
	_scene._refresh_route_status()
	_scene._refresh_scan_status()
	if _scene.narrative != null:
		_scene.narrative.legacy_conclusion = bool(saved.get("legacy_conclusion",false))
	vessel.reset_physics_interpolation()
	var camera: Camera2D = vessel.get_node("Camera2D") as Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()
	_busy = false
	checkpoint_restored.emit()
	return _report("Continued at clear Shelf Base fallback; supplies/progress preserved, temporary route reset." if relocated else "Expedition restored. Temporary echoes, contacts and creature pursuit cleared.", OK)


func recover_backup() -> Error:
	if not FileAccess.file_exists(store.path) and not FileAccess.file_exists(store.path + ".bak"):
		return _recover_legacy()
	if _busy:
		return ERR_BUSY
	_busy = true
	var restored: Dictionary = store.recover_checkpoint(progress_snapshot(),prototype_snapshot(),_scene.story.snapshot(),journey_snapshot())
	if restored.error == OK:
		_state = restored.data
		_has_checkpoint = true
		_ready_to_write = true
		_delegate_stores()
		_scene.story.restore(_state.story)
		apply_progress(_state.progress)
		if _scene.bloom!=null: _scene.bloom.refresh_state()
		if _scene.journey!=null:
			# Recover metadata now; apply geometry/pose only through the explicit Continue.
			_scene.journey.state = _state.journey.duplicate(true)
			_scene._expedition_started = false
			_scene.submarine.set_simulation_enabled(false)
	_report("Backup recovered; rejected file preserved. Continue to resume." if restored.error == OK else "Backup not recovered (%s); files/vessel preserved." % error_string(restored.error), restored.error)
	_busy = false
	return restored.error


func new_expedition() -> Error:
	if not _ready_to_write or _busy or _scene.submarine.is_physics_processing() or not position_clear(_scene.region.spawn.global_position, 0.0):
		return _report("New Expedition blocked: recover checkpoint or pause safely first.", ERR_UNAVAILABLE)
	var candidate: Dictionary = snapshot()
	candidate.player = {"position": [_scene.region.spawn.global_position.x, _scene.region.spawn.global_position.y], "rotation": 0.0,
		"hull": _scene.submarine.hull_system.max_hull, "battery": _scene.submarine.resource_system.max_battery,
		"oxygen": _scene.submarine.resource_system.max_oxygen, "sonar_cooldown": 0.0}
	candidate.route = {"stage": 0, "elapsed_seconds": 0.0}
	var result: Error = _write(candidate, "New Expedition checkpoint saved; all permanent progress retained.")
	return continue_expedition() if result == OK else result


func can_write() -> bool:
	return _ready_to_write


func _recover_legacy() -> Error:
	if _busy:
		return ERR_BUSY
	var pending: Array[int] = []
	var stores: Array = [_scene.discovery_store, _scene.research_store, _scene.upgrades.store, _scene.missions.store]
	for index: int in range(stores.size()):
		var legacy: Variant = stores[index]
		if legacy.last_result == OK or (legacy.last_result == ERR_FILE_NOT_FOUND and not FileAccess.file_exists(legacy.path + ".bak")):
			continue
		var inspected: Dictionary
		match index:
			0: inspected = legacy._read(legacy.path + ".bak", _scene.discoveries)
			1: inspected = legacy._read(legacy.path + ".bak", _scene.research)
			2: inspected = legacy._read(legacy.path + ".bak", ExpeditionSchema.UPGRADES)
			3: inspected = legacy._read(legacy.path + ".bak", ExpeditionSchema.MISSIONS)
		if inspected.error != OK or FileAccess.file_exists(legacy.path + ".rejected"):
			return _report("Legacy backup unavailable or rejected-file conflict; migration cancelled, files preserved.", ERR_INVALID_DATA)
		pending.append(index)
	if pending.is_empty():
		return _report("No expedition or legacy backup available; nothing changed.", ERR_FILE_NOT_FOUND)
	_busy = true
	for index: int in pending:
		var result: Error
		match index:
			0: result = _scene.discovery_store.recover_backup(_scene.discoveries)
			1: result = _scene.research_store.recover_backup(_scene.research)
			2: result = _scene.upgrades.recover_backup()
			3: result = _scene.missions.recover_backup()
		if result != OK:
			_busy = false
			return _report("Legacy recovery incomplete; play remains blocked. Inspect preserved files.", result)
	_busy = false
	var configured: Error = setup(_scene, store.path)
	if configured != OK:
		return configured
	return save_current()


func is_restoring() -> bool:
	return _busy

func prototype_snapshot() -> Dictionary:
	if _scene.revision != null: return _scene.revision.snapshot()
	return _state.get("prototype",{"ammunition":10,"campaign":CampaignData.migrate(progress_snapshot())}).duplicate(true)
func commit_prototype(value: Dictionary) -> Error:
	if not ExpeditionSchema.valid_prototype(value): return ERR_INVALID_DATA
	var candidate: Dictionary = _state.duplicate(true)
	candidate.prototype = value.duplicate(true)
	return _write(candidate,"Research and expedition state saved.")

func commit_story(value: Dictionary, choice_id: StringName) -> Error:
	if _busy or not _ready_to_write or not StoryState.valid_snapshot(value): return ERR_UNAVAILABLE
	var candidate: Dictionary = _state.duplicate(true)
	candidate.story = value.duplicate(true)
	candidate.progress = progress_snapshot()
	candidate.prototype = prototype_snapshot()
	candidate.terrain = _scene.excavation.snapshot() if _scene.excavation!=null else []
	if choice_id!=&"":
		var choice: ChoiceData = _scene.story.definition(choice_id)
		if choice==null: return ERR_INVALID_PARAMETER
		if choice.encounter_id==TwilightShelfData.ENCOUNTER:
			if _scene.journey==null or not _scene.journey.active(): return ERR_UNAVAILABLE
			if choice_id in [TwilightShelfData.RELEASE,TwilightShelfData.CAPTURE] and (not _scene.journey.expedition.near_net() or not _scene.research.is_completed(&"twilight-net-survey")): return ERR_UNAUTHORIZED
			if not position_clear(_scene.submarine.global_position,_scene.submarine.rotation) or _scene.submarine.hull_system.hull<=0 or _scene.journey.habitat.unsafe_at(_scene.submarine.global_position): return ERR_UNAVAILABLE
			candidate.player = snapshot().player
			candidate.route = snapshot().route
		if choice.research_record_id!=&"" and String(choice.research_record_id) not in candidate.progress.research:
			candidate.progress.research.append(String(choice.research_record_id))
			candidate.progress.research.sort()
	var awards: Array[StringName] = []
	if _scene.chapter!=null and _scene.chapter.active and choice_id!=&"":
		var definition: ChoiceData = _scene.story.definition(choice_id)
		if definition.research_record_id!=&"": awards.append(definition.research_record_id)
	return _write(candidate,"Story decision saved with expedition progress.",awards)

func commit_research_checkpoint(proposed: Array[StringName]) -> Error:
	# Evidence recovery is an explicit, safe local checkpoint, not a periodic autosave.
	if _busy or not _ready_to_write or _scene.submarine.hull_system.hull<=0 or _scene.submarine.resource_system.oxygen<=0 \
		or not position_clear(_scene.submarine.global_position,_scene.submarine.rotation) \
		or _scene.submarine.damage_system.warning_state==SubmarineDamageSystem.WarningState.EXCEEDED \
		or _scene.predator.threat.phase in [PredatorState.Phase.ALERT,PredatorState.Phase.PURSUE]: return ERR_UNAVAILABLE
	var candidate: Dictionary = snapshot()
	candidate.progress.research = _strings(proposed)
	if not ExpeditionSchema.valid_progress(candidate.progress): return ERR_INVALID_DATA
	var awards: Array[StringName] = []
	if (_scene.chapter!=null and _scene.chapter.active) or (_scene.journey!=null and _scene.journey.active()):
		for id: StringName in proposed:
			if not _scene.research.is_completed(id):
				if not _scene.submarine.scanner.eligible(id): return ERR_UNAUTHORIZED
				awards.append(id)
	return _write(candidate,"Scientific record and safe vessel checkpoint saved together.",awards)

func begin_new_campaign(replacement: ExpeditionStore = null) -> Error:
	# Explicit title confirmation only. Archive ALL campaign stores to prevent legacy reimport.
	if _busy or _scene.submarine.is_physics_processing(): return ERR_BUSY
	var candidate: Dictionary = snapshot()
	candidate.story = StoryState.fresh()
	candidate.journey = ExpeditionJourneyState.fresh()
	candidate.region_id = ExpeditionSchema.REGION
	candidate.legacy_conclusion = false
	candidate.progress = {"discoveries":[],"research":[],"upgrades":[],"missions":_scene.missions._catalog.initial_records()}
	candidate.prototype = {"ammunition":TorpedoLauncher.CAPACITY,"campaign":CampaignData.fresh()}
	candidate.terrain = []
	candidate.route = {"stage":0,"elapsed_seconds":0.0}
	candidate.player = {"position":[_scene.region.spawn.global_position.x,_scene.region.spawn.global_position.y],"rotation":0.0,"hull":_scene.submarine.hull_system.max_hull,"battery":_scene.submarine.resource_system.max_battery,"oxygen":_scene.submarine.resource_system.max_oxygen,"sonar_cooldown":0.0}
	if _scene.chapter!=null: candidate.player.position = [SunlitSurveyData.SPAWN.x,SunlitSurveyData.SPAWN.y]
	if ExpeditionSchema.decode(candidate).error!=OK: return ERR_INVALID_DATA
	var paths: Array[String] = [store.path]
	for legacy: Variant in [_scene.discovery_store,_scene.research_store,_scene.upgrades.store,_scene.missions.store]:
		if legacy.path not in paths: paths.append(legacy.path)
	var archive: String = store.path.get_base_dir().path_join("campaign-archive-%d-%d" % [int(Time.get_unix_time_from_system()),Time.get_ticks_usec()])
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(archive)): return ERR_ALREADY_EXISTS
	var error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(archive))
	if error!=OK: return _report("New Game cancelled: archive unavailable; current campaign preserved.",error)
	last_campaign_archive = archive
	_busy = true
	var moved: Array[Dictionary] = []
	var writing_candidate: bool = false
	for index: int in range(paths.size()):
		for suffix: String in ["",".bak",".tmp",".invalid",".rejected"]:
			var original: String = ProjectSettings.globalize_path(paths[index]+suffix)
			if not FileAccess.file_exists(original): continue
			var destination: String = ProjectSettings.globalize_path(archive.path_join(str(index)+"-"+paths[index].get_file()+suffix))
			error = DirAccess.rename_absolute(original,destination)
			if error!=OK: break
			moved.append({"from":original,"to":destination})
		if error!=OK: break
	if error==OK:
		writing_candidate = true
		var writer: ExpeditionStore = replacement if replacement!=null else ExpeditionStore.new()
		writer.path = store.path
		writer.load_checkpoint()
		error = writer.write_checkpoint(candidate)
	if error!=OK:
		# Discard only this operation's new candidate, then restore the archived originals.
		for suffix: String in ["",".bak",".tmp"]:
			var generated: String = ProjectSettings.globalize_path(store.path+suffix)
			if writing_candidate and FileAccess.file_exists(generated):
				DirAccess.remove_absolute(generated)
		moved.reverse()
		for item: Dictionary in moved:
			var rollback: Error = DirAccess.rename_absolute(item.to,item.from)
			if rollback!=OK:
				_busy = false
				return _report("Campaign retained in archive; automatic rollback failed. Archive: "+archive,rollback)
		_busy = false
		return _report("New Game cancelled; previous campaign restored. Settings unchanged.",error)
	_busy = false
	return _report("New campaign created. Previous campaign archived at "+archive,OK)

func journey_snapshot() -> Dictionary:
	return _scene.journey.snapshot() if _scene.journey!=null else _state.get("journey",ExpeditionJourneyState.fresh()).duplicate(true)

func _transfer_player(candidate: Dictionary,at: Vector2,restock: bool) -> void:
	candidate.player.position = [at.x,at.y]
	candidate.player.rotation = 0.0
	candidate.player.sonar_cooldown = 0.0
	candidate.route = {"stage":0,"elapsed_seconds":0.0}
	if restock:
		candidate.player.hull = _scene.submarine.hull_system.max_hull
		candidate.player.battery = _scene.submarine.resource_system.max_battery
		candidate.player.oxygen = _scene.submarine.resource_system.max_oxygen
		candidate.prototype.ammunition = 10

func finish_sunlit_return() -> Error:
	if _scene.journey==null or not _scene.journey.can_finish() or not safe_to_save(): return ERR_UNAVAILABLE
	var service: Dictionary = _scene.station.quote_arrival_service(_scene.submarine)
	if not service.has("after"): return service.error
	var plan: Dictionary = _scene.missions.plan_scripted_return(SunlitShallowsData.MISSION)
	if plan.error!=OK: return plan.error
	var candidate: Dictionary = snapshot()
	candidate.progress.missions = plan.records
	_transfer_player(candidate,SunlitSurveyData.SPAWN,true)
	for kind: String in ["hull","battery","oxygen"]: candidate.player[kind] = service.after[kind]
	var result: Error = _write(candidate,"Expedition acknowledged; off-screen voyage and service saved.")
	if result!=OK: return result
	result = continue_expedition()
	if result==OK:
		if plan.completed: _scene.missions.mission_completed.emit(SunlitShallowsData.MISSION)
		_scene.missions.acknowledgement_claimed.emit(SunlitShallowsData.MISSION,plan.acknowledgement)
	return result

func transfer_chapter(phase: String,restock: bool) -> Error:
	if _scene.journey==null or _busy or not _ready_to_write or _scene.submarine.is_physics_processing() or phase not in ["twilight","refit"]: return ERR_UNAVAILABLE
	var old: Dictionary = journey_snapshot()
	if phase=="refit" and (not _scene.journey.near_tether() or not restock): return ERR_UNAVAILABLE
	if phase=="twilight" and (old.phase not in ["sunlit","refit"] or restock==old.commissioned): return ERR_UNAVAILABLE
	if not _scene.chapter.concluded(): return ERR_UNAVAILABLE
	var service: Dictionary = _scene.station.quote_arrival_service(_scene.submarine) if phase=="refit" else {}
	if phase=="refit" and not service.has("after"): return service.error
	var candidate: Dictionary = snapshot()
	candidate.journey = {"phase":phase,"commissioned":true}
	var twilight_record: Dictionary = candidate.progress.missions[String(TwilightShelfData.MISSION)]
	if phase=="twilight" and twilight_record.state=="available": twilight_record.state = "accepted"
	if phase=="refit" and twilight_record.state in ["accepted","completed"]:
		var plan: Dictionary = _scene.missions.plan_scripted_return(TwilightShelfData.MISSION)
		if plan.error==OK:
			candidate.progress.missions = plan.records
			candidate.progress.missions[String(TwilightShelfData.MISSION)].state = "completed"
	candidate.region_id = ExpeditionJourneyState.region(candidate.journey)
	_transfer_player(candidate,TwilightShelfLayout.SPAWN if phase=="twilight" else SunlitSurveyData.SPAWN,restock)
	if phase=="refit":
		for kind: String in ["hull","battery","oxygen"]: candidate.player[kind] = service.after[kind]
	var completed_now: bool = phase=="refit" and _scene.missions.snapshot()[String(TwilightShelfData.MISSION)].state=="accepted" and candidate.progress.missions[String(TwilightShelfData.MISSION)].state=="completed"
	var result: Error = _write(candidate,"Chapter transfer committed; expedition progress preserved.")
	if result!=OK: return result
	result = continue_expedition()
	if result==OK and completed_now: _scene.missions.mission_completed.emit(TwilightShelfData.MISSION)
	return result

func transfer_prototype() -> Error:
	if _scene.journey==null or _busy or not _ready_to_write or _scene.submarine.is_physics_processing(): return ERR_UNAVAILABLE
	var candidate: Dictionary = snapshot()
	candidate.journey.phase = "prototype"
	candidate.region_id = ExpeditionSchema.REGION
	_transfer_player(candidate,_scene.chapter._old_spawn,false)
	var result: Error = _write(candidate,"Prototype expedition selected; canonical records preserved.")
	return continue_expedition() if result==OK else result
