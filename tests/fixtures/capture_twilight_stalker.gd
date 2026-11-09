extends SceneTree
var game: ShelfPrototype
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for tick: int in range(n): await process_frame
func capture(label: String) -> void:
	await frames(5)
	RenderingServer.force_draw(false,0)
	await frames(2)
	var result: Error = root.get_texture().get_image().save_png(OS.get_environment("BTA_EVIDENCE_DIR")+"/%s-%dx%d.png" % [label,root.size.x,root.size.y])
	if result!=OK: quit(1)
func run() -> void:
	for size: Vector2i in [Vector2i(1280,800),Vector2i(800,600)]:
		root.size = size
		game = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
		game.settings_path = "user://bta060-capture-%d.json" % Time.get_ticks_usec()
		game.expedition_path = game.settings_path+".expedition.json"
		root.add_child(game)
		await frames(5)
		game.journey.prepare({"phase":"twilight","commissioned":true})
		game.upgrades.reapply()
		var onboarding: Dictionary = game.settings.snapshot().onboarding
		onboarding.enabled = false
		game.settings.set_onboarding(onboarding)
		game.revision.ui.title_page.hide()
		game.route_layer.hide()
		var actor: RiftStalker = game.journey.hunt.actors[0]
		game.submarine.global_position = actor.global_position-Vector2(actor.hunt.profile.sense_radius*0.45,0)
		game.resume_route()
		actor.set_physics_process(false)
		game.torpedoes.set_physics_process(false)
		var camera: Camera2D = game.submarine.get_node("Camera2D") as Camera2D
		game.submarine.reset_physics_interpolation()
		camera.reset_physics_interpolation()
		for tick: int in range(4): await physics_frame
		camera.reset_smoothing()
		camera.force_update_scroll()
		await frames(12)
		var ping: Error = game.submarine.sonar.request_ping()
		actor.hunt.sense(game.submarine.global_position,true,true)
		actor.hunt.advance(0.01,actor.position)
		actor._refresh()
		if ping!=OK or actor.hunt.phase!=RiftStalkerState.Phase.WARNING:
			push_error("Capture did not receive an actual ping")
			quit(1)
			return
		await capture("warning")
		actor.hunt.advance(actor.hunt.profile.warning_seconds,actor.position)
		actor._refresh()
		await capture("pursuit")
		var fired: Error = game.torpedoes.request_fire()
		if fired!=OK:
			quit(1)
			return
		var projectile: TorpedoProjectile = game.torpedoes._projectiles.back()
		for tick: int in range(240):
			projectile.advance(1.0/120.0)
			if projectile.exploded: break
		actor._refresh()
		if actor.hunt.phase!=RiftStalkerState.Phase.STUN:
			push_error("Capture aimed shot did not scare the actor")
			quit(1)
			return
		await capture("scare")
		print("BTA060_FRAME size=",size," process_ms=",Performance.get_monitor(Performance.TIME_PROCESS)*1000," physics_ms=",Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		game.queue_free()
		await frames(3)
	print("BTA060_CAPTURE_PASS")
	quit()
