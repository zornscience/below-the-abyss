class_name ReleaseSmoke
extends Node
## Runs in the actual exported application when explicitly requested.
## Limited to the playtest export: ordinary builds ignore the flag entirely.
func _ready() -> void:
	if not OS.has_feature("playtest") or not OS.get_cmdline_user_args().has("--release-smoke"): return
	call_deferred("_verify")
## assert() is stripped from release exports, so prove the Twilight sonar and discovery
## registrations exist in this exact binary: every echo, the sentinel and the net contact.
func _verify_registration(game: ShelfPrototype) -> bool:
	var bus: AcousticBus = game.get_node_or_null("AcousticBus") as AcousticBus
	var expedition: TwilightExpedition = game.journey.expedition if game.journey!=null else null
	if bus==null or expedition==null or expedition.echoes().is_empty(): return false
	if OS.get_cmdline_user_args().has("--break-registration-wiring"):
		expedition.echoes()[0].bind_bus(null)
	for echo: SonarRevealTarget in expedition.echoes():
		if echo.receiver.get_bus()!=bus or not game.submarine.sonar.is_listening_to(echo) or not game.discoveries.is_sonar_bound(echo):
			push_error("RELEASE_REGISTRATION_WIRING_FAIL echo "+String(echo.target_id))
			return false
	if expedition.sentinel==null or expedition.sentinel.receiver.get_bus()!=bus:
		push_error("RELEASE_REGISTRATION_WIRING_FAIL sentinel")
		return false
	if expedition.contact==null or expedition.contact.emitter.get_bus()!=bus:
		push_error("RELEASE_REGISTRATION_WIRING_FAIL net contact")
		return false
	print("RELEASE_REGISTRATION_WIRING_PASS")
	return true
func _verify() -> void:
	var game: ShelfPrototype = get_parent() as ShelfPrototype
	if not _verify_registration(game):
		get_tree().quit(1)
		return
	var view: TwilightVisibility = game.journey.visibility
	if view!=null and OS.get_cmdline_user_args().has("--break-visibility-wiring"):
		game.submarine.sonar.pulse_emitted.disconnect(view._ping)
	if view==null or view.material==null or view.contours.get_child_count()<game.journey.layout.bodies.size() or not game.submarine.sonar.pulse_emitted.is_connected(view._ping):
		push_error("RELEASE_VISIBILITY_WIRING_FAIL")
		get_tree().quit(1)
		return
	if not game.journey.habitat.ambient.get_child_count()>0:
		get_tree().quit(1)
		return
	game.journey.prepare({"phase":"twilight","commissioned":true})
	# Continue and refitting reapply upgrade profiles after regional preparation.
	game.upgrades.reapply()
	if OS.get_cmdline_user_args().has("--break-resource-wiring"):
		game.submarine.sonar.set_battery_cost(game.journey._shallow_ping_cost)
		game.torpedoes.set_battery_cost(game.journey._shallow_torpedo_cost)
	var costs: ActionCostProfile = ChapterJourney.ACTION_COSTS
	if game.submarine.sonar.battery_cost()!=costs.ping_battery or game.torpedoes.battery_cost()!=costs.torpedo_battery:
		push_error("RELEASE_RESOURCE_WIRING_FAIL")
		get_tree().quit(1)
		return
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	(game.get_node("WorldRoot") as Node2D).show()
	game.submarine.set_simulation_enabled(true)
	var battery_before: float = game.submarine.resource_system.battery
	var emitted: Error = game.submarine.sonar.request_ping()
	if emitted!=OK or view.speeds[0]<=0:
		push_error("RELEASE_VISIBILITY_EMISSION_FAIL")
		get_tree().quit(1)
		return
	if not is_equal_approx(game.submarine.resource_system.battery,battery_before-costs.ping_battery):
		push_error("RELEASE_RESOURCE_WIRING_FAIL ping debit")
		get_tree().quit(1)
		return
	var fired: Error = game.torpedoes.request_fire()
	if fired!=OK or not is_equal_approx(game.submarine.resource_system.battery,battery_before-costs.ping_battery-costs.torpedo_battery):
		push_error("RELEASE_RESOURCE_WIRING_FAIL torpedo debit")
		get_tree().quit(1)
		return
	print("RELEASE_RESOURCE_WIRING_PASS")
	game.submarine.sonar.advance(0.25)
	view._process(0)
	if view.pings[0].z<0.24 or not view.veil.visible:
		push_error("RELEASE_VISIBILITY_CLOCK_FAIL")
		get_tree().quit(1)
		return
	print("RELEASE_VISIBILITY_WIRING_PASS")
	await _verify_depth_gate(game)

func _verify_depth_gate(game: ShelfPrototype) -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var rank_before: int = game.revision.campaign.ranks.hull
	for rank: int in range(4):
		game.revision.campaign.ranks.hull = rank
		game.upgrades.reapply()
		if args.has("--break-depth-rating-wiring"): game.submarine.damage_system.set_maximum_depth_m(300)
		var expected: float = game.revision.tree.hull_ratings[rank]+ChapterJourney.PRESSURE_FIT.baseline_safe_depth_m-game.revision.tree.hull_ratings[0]
		if game.submarine.damage_system.get_maximum_depth_m()!=expected:
			push_error("RELEASE_DEPTH_RATING_WIRING_FAIL")
			get_tree().quit(1)
			return
	game.revision.campaign.ranks.hull = rank_before
	game.upgrades.reapply()
	var gate: DepthGateProfile = TwilightShelfLayout.DEPTH_GATE
	if args.has("--break-depth-section-wiring"): game.journey.layout.set_enabled(false)
	var registered: bool = game.submarine.scanner._known(&"twilight-deep-crust") and game.journey.layout.visible and Rect2(game.region.camera_bounds).has_point(gate.lower_left)
	for rock: GrayboxRock in game.journey.layout.bodies:
		registered = registered and rock.collision_layer==1
	if not registered:
		push_error("RELEASE_DEPTH_SECTION_WIRING_FAIL")
		get_tree().quit(1)
		return
	var flow: TwilightDepthGate = game.journey.depth_gate
	if args.has("--break-failure-wiring"): game.submarine.hull_system.vessel_destroyed.disconnect(flow._destroyed)
	if not game.submarine.hull_system.vessel_destroyed.is_connected(flow._destroyed):
		push_error("RELEASE_FAILURE_WIRING_FAIL")
		get_tree().quit(1)
		return
	game.submarine.hull_system.apply_damage(game.submarine.hull_system.hull,&"pressure")
	await get_tree().process_frame
	await get_tree().process_frame
	if not flow.pending or not flow.panel.visible or game.submarine.is_physics_processing():
		push_error("RELEASE_FAILURE_WIRING_FAIL presentation")
		get_tree().quit(1)
		return
	print("RELEASE_DEPTH_GATE_PASS")
	get_tree().quit()
