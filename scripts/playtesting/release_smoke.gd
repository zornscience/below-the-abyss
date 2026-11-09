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
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	(game.get_node("WorldRoot") as Node2D).show()
	game.submarine.set_simulation_enabled(true)
	var emitted: Error = game.submarine.sonar.request_ping()
	if emitted!=OK or view.speeds[0]<=0:
		push_error("RELEASE_VISIBILITY_EMISSION_FAIL")
		get_tree().quit(1)
		return
	game.submarine.sonar.advance(0.25)
	view._process(0)
	if view.pings[0].z<0.24 or not view.veil.visible:
		push_error("RELEASE_VISIBILITY_CLOCK_FAIL")
		get_tree().quit(1)
		return
	print("RELEASE_VISIBILITY_WIRING_PASS")
	get_tree().quit()
