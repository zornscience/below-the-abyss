extends SceneTree
## Offline UI thumbnails from actual first-party visuals. No network or runtime generator.
func _render(subject: Node2D,center: Vector2,zoom: float,path: String) -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(256,128)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	subject.position = Vector2(128,64)-center*zoom
	subject.scale = Vector2.ONE*zoom
	viewport.add_child(subject)
	for unused: int in range(3): await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(path)==OK)
	viewport.queue_free()
	await process_frame
func _initialize() -> void:
	var bloom: LightBloomVisual = LightBloomVisual.new()
	bloom.reduced_effects = true
	await _render(bloom,Vector2.ZERO,1.5,"res://assets/art/sunlit/bloom_thumbnail.png")
	await _render(ShelfStoryDetails.new(),Vector2(760,502),3.0,"res://assets/art/sunlit/plate_thumbnail.png")
	print("SCIENCE_THUMBNAILS_RENDER_PASS")
	quit()
