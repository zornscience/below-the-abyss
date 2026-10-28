extends "res://tests/fixtures/drive_sunlit_environment.gd"
## Real-input route. At meaningful milestones only, redraw the same live state
## at all resolutions/comfort modes, then restore the route's original settings.
const MATRIX: Array[String] = ["expanded-map","rockfall-before","rockfall-after","fish-school",
	"scan-sunlit-silver-shoal","vent-safe","vent-danger","sonar-travelling",
	"sonar-buoy-arrival","research-xp","debrief"]

func _capture(name: String) -> void:
	if _captures.is_empty(): return
	if name not in MATRIX:
		await super._capture(name)
		return
	var original_size: Vector2i = root.size
	var original: Dictionary = _scene.settings.snapshot().accessibility
	for dimensions: Vector2i in [Vector2i(800,600),Vector2i(1280,800),Vector2i(1920,1080)]:
		for reduced: bool in [false,true]:
			root.size = dimensions
			var prefs: Dictionary = original.duplicate(true)
			prefs.reduced_motion = reduced
			prefs.reduced_flashing = reduced
			prefs.reduced_particles = reduced
			prefs.ui_scale = "large" if reduced and dimensions.x==800 else "standard"
			prefs.high_contrast = reduced and dimensions.x==800
			_scene.settings.set_accessibility(prefs)
			for unused: int in range(3): await process_frame
			RenderingServer.force_draw(false,0.0)
			var shot: Image = root.get_texture().get_image()
			assert(shot.get_size()==dimensions)
			assert(shot.save_png(_captures.path_join("%d-%s-%s.png" % [dimensions.x,"reduced" if reduced else "normal",name]))==OK)
	root.size = original_size
	_scene.settings.set_accessibility(original)
	for unused: int in range(3): await process_frame
