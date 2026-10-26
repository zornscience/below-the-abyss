extends GutTest


func test_presentation_preserves_vessel_collision_and_only_flips_visual_facing() -> void:
	var body: SubmarineController = load("res://scenes/player/submarine.tscn").instantiate() as SubmarineController
	add_child_autofree(body)
	body.set_simulation_enabled(false)
	var shape: CapsuleShape2D = (body.get_node("CollisionShape2D") as CollisionShape2D).shape as CapsuleShape2D
	assert_eq(shape.radius, 16.0)
	assert_eq(shape.height, 64.0)
	assert_eq(body.collision_layer, 2)
	var rotation_before: float = body.rotation
	var visual: Node2D = body.get_node("Visual") as Node2D
	body.velocity = Vector2(-100, 40)
	visual.call("_process", 0.1)
	assert_eq(visual.scale.x, -1.0)
	assert_eq(body.velocity, Vector2(-100, 40))
	assert_eq(body.rotation, rotation_before)
	assert_eq(body.resource_system.battery, 100.0)
	assert_not_null((visual.get_node("NerisIllustration") as Sprite2D).texture)


func test_shelf_layers_are_decorative_and_solid_silhouettes_still_match_boundaries() -> void:
	var region: ContinentalShelf = load("res://scenes/regions/continental_shelf.tscn").instantiate() as ContinentalShelf
	add_child_autofree(region)
	assert_true(region.get_node("Atmosphere") is Parallax2D)
	assert_eq(region.get_node("Terrain").get_child_count(), 10)
	for node: Node in region.get_node("Terrain").get_children():
		var rock: GrayboxRock = node as GrayboxRock
		assert_eq((rock.get_node("Silhouette") as Polygon2D).polygon, rock.outline)
		assert_eq((rock.get_node("Boundary") as CollisionPolygon2D).polygon, rock.outline)
		assert_eq(rock.collision_layer, 1)
	assert_eq(region.get_node("Atmosphere").get_child_count(), 3)
