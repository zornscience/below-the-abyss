extends "res://tests/fixtures/drive_sunlit_shallows.gd"
## Reuse the complete real-input route; render only evidence on software-only hosts.
## Run with --disable-render-loop. This is not a realtime performance measurement.

func _capture(name: String) -> void:
	if _captures.is_empty(): return
	await process_frame
	RenderingServer.force_draw(false,0.0)
	var shot: Image = root.get_texture().get_image()
	assert(shot.get_size()==root.size)
	assert(shot.save_png(_captures.path_join(_outcome+"-"+name+("-small" if _small else "")+".png"))==OK)
