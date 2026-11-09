class_name ReleaseSmoke
extends Node
## Runs in the actual exported application when explicitly requested.
func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--release-smoke"): return
	call_deferred("_verify")
func _verify() -> void:
	var game: ShelfPrototype = get_parent() as ShelfPrototype
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
