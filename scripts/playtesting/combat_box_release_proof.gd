class_name CombatBoxReleaseProof
extends Node
## Survives the real scene transition. No assertions: this executes in release.
func start(game: ShelfPrototype) -> void:
	var panel: PlaytestPanel = game.playtest_panel
	if panel==null or panel.combat_button==null:
		_fail("ENTRY")
		return
	panel.present(game.playtest_observer)
	if OS.get_cmdline_user_args().has("--break-combat-entry-wiring"):
		panel.combat_button.pressed.disconnect(panel._open_combat_box)
	panel.combat_button.pressed.emit()
	_verify.call_deferred()
func _fail(wiring: String) -> void:
	push_error("RELEASE_COMBAT_"+wiring+"_WIRING_FAIL")
	get_tree().quit(1)
func _verify() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var box: CombatBox = get_tree().current_scene as CombatBox
	if box==null or box.submarine==null or box.swarmers.size()!=CombatBox.DATA.swarm_spawns.size():
		_fail("ENTRY")
		return
	print("RELEASE_COMBAT_ENTRY_WIRING_PASS")
	box.resume()
	if OS.get_cmdline_user_args().has("--break-combat-registration-wiring"): box.swarmers[0].bind_bus(null)
	for actor: CombatSwarmer in box.swarmers:
		if actor.receiver.get_bus()!=box.bus or not actor.receiver.enabled:
			_fail("REGISTRATION")
			return
	if OS.get_cmdline_user_args().has("--break-combat-stalker-registration-wiring"): box.stalker.bind_bus(null)
	print("RELEASE_COMBAT_REGISTRATION_WIRING_PASS")
	if box.stalker.receiver.get_bus()!=box.bus or not box.stalker.receiver.enabled or box.stalker.damageable:
		_fail("STALKER_REGISTRATION")
		return
	print("RELEASE_COMBAT_STALKER_REGISTRATION_WIRING_PASS")
	box.submarine.global_position = CombatBox.DATA.stun_probe
	box.submarine.velocity = Vector2.ZERO
	await get_tree().physics_frame
	if OS.get_cmdline_user_args().has("--break-combat-stun-wiring"): box.submarine.sonar.pulse_emitted.disconnect(box.stun._ping)
	var battery: float = box.submarine.resource_system.battery
	var ping: Error = box.submarine.sonar.request_ping()
	if ping!=OK or box.swarmers[0].model.phase!=SwarmerState.Phase.STUN or box.stalker.hunt.phase==RiftStalkerState.Phase.STUN or not is_equal_approx(box.submarine.resource_system.battery,battery-CombatBox.COSTS.ping_battery):
		_fail("STUN")
		return
	print("RELEASE_COMBAT_STUN_WIRING_PASS")
	box.open_options()
	if OS.get_cmdline_user_args().has("--break-combat-handling-wiring"): box.responsive_button.pressed.disconnect(box._responsive)
	box.responsive_button.pressed.emit()
	if box.submarine.motion!=CombatHandling.RESPONSIVE or box.profile_id!="responsive":
		_fail("HANDLING")
		return
	print("RELEASE_COMBAT_HANDLING_WIRING_PASS")
	if OS.get_cmdline_user_args().has("--break-combat-weighty-handling-wiring"): box.weighty_button.pressed.disconnect(box._weighty)
	box.weighty_button.pressed.emit()
	if box.submarine.motion!=CombatHandling.WEIGHTY or box.profile_id!="weighty":
		_fail("WEIGHTY_HANDLING")
		return
	print("RELEASE_COMBAT_WEIGHTY_HANDLING_WIRING_PASS")
	get_tree().quit()
