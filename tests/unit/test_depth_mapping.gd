extends GutTest


func test_surface_reference_scale_and_above_water_clamping() -> void:
	var mapping: DepthMapping = DepthMapping.new()
	assert_eq(mapping.depth_at_local(Vector2(100.0, 0.0)), 0.0)
	assert_eq(mapping.depth_at_local(Vector2(-500.0, 520.0)), 130.0)
	assert_eq(mapping.depth_at_local(Vector2(0.0, 1200.0)), 300.0)
	assert_eq(mapping.depth_at_local(Vector2(0.0, -200.0)), 0.0)
	mapping.water_surface_local_y = -400.0
	mapping.meters_per_unit = 0.5
	assert_eq(mapping.depth_at_local(Vector2.ZERO), 200.0, "Authored region offsets come from the explicit surface reference.")


func test_region_transforms_are_applied_before_depth_conversion() -> void:
	var region: DepthRegion = DepthRegion.new()
	region.position = Vector2(800.0, -300.0)
	region.rotation = 0.2
	region.scale = Vector2(2.0, 1.5)
	add_child_autofree(region)
	var world: Vector2 = region.to_global(Vector2(70.0, 1200.0))
	assert_almost_eq(region.depth_at_world(world), 300.0, 0.001)
	region.position += Vector2(-1000.0, 500.0)
	assert_almost_eq(region.depth_at_world(region.to_global(Vector2(70.0, 1200.0))), 300.0, 0.001)


func test_invalid_mapping_coordinates_and_singular_transform_are_rejected() -> void:
	var mapping: DepthMapping = DepthMapping.new()
	for value: float in [0.0, -1.0, NAN, INF]:
		mapping.meters_per_unit = value
		assert_false(mapping.is_valid())
		assert_true(is_nan(mapping.depth_at_local(Vector2.ZERO)))
	mapping.meters_per_unit = 0.25
	mapping.water_surface_local_y = NAN
	assert_false(mapping.is_valid())
	mapping.water_surface_local_y = 0.0
	assert_true(is_nan(mapping.depth_at_local(Vector2(INF, 10.0))))
	var region: DepthRegion = DepthRegion.new()
	add_child_autofree(region)
	region.transform = Transform2D(Vector2.ZERO, Vector2.DOWN, Vector2.ZERO)
	assert_true(is_nan(region.depth_at_world(Vector2.ZERO)))
