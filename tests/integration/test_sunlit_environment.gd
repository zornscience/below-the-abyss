extends GutTest
const MAIN: PackedScene = preload("res://scenes/main/main.tscn")
var game: ShelfPrototype
var path: String

func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(),0.25)
	game = MAIN.instantiate() as ShelfPrototype
	path = "user://bta050-art-%d.json" % Time.get_ticks_usec()
	game.settings_path = path
	game.expedition_path = path+".expedition.json"
	add_child_autofree(game)
	game.chapter.start()
	game.chapter.launch()
	game.submarine.set_simulation_enabled(false)
	await wait_process_frames(6)

func after_each() -> void:
	for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".invalid", ".rejected"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+stem+suffix))

func fingerprint() -> Array[String]:
	var result: Array[String] = []
	for node: Node in game.region.find_children("*","CollisionPolygon2D",true,false):
		result.append(str(node.global_transform,node.polygon))
	for node: Node in game.region.find_children("*","CollisionShape2D",true,false):
		var shape: CollisionShape2D = node as CollisionShape2D
		var data: Variant = shape.shape.size if shape.shape is RectangleShape2D else shape.shape.get_class()
		result.append(str(shape.global_transform,data))
	result.sort()
	return result

func test_art_contains_no_bodies_targets_or_progress_and_clock_cannot_move_player() -> void:
	var art: SunlitDressing = game.chapter.dressing
	assert_true(art.is_visible_in_tree())
	assert_true(art.find_children("*","CollisionObject2D",true,false).is_empty())
	assert_true(art.find_children("*","SonarRevealTarget",true,false).is_empty())
	assert_true(art.find_children("*","ScientificScanTarget",true,false).is_empty())
	var geometry: Array[String] = fingerprint()
	var checkpoint: Dictionary = game.saves._state.duplicate(true)
	var at: Vector2 = game.submarine.position
	var bounds: Rect2i = game.region.camera_bounds
	art.set_simulating(true)
	for unused: int in range(30): art._process(1.0/30.0)
	assert_gt(art.phase,0.9)
	assert_eq(game.submarine.position,at)
	assert_eq(game.submarine.velocity,Vector2.ZERO)
	assert_eq(game.saves._state,checkpoint)
	assert_eq(fingerprint(),geometry)
	assert_eq(game.region.camera_bounds,bounds)

func test_comfort_preferences_freeze_parallax_plants_and_particles_without_changing_state() -> void:
	var art: SunlitDressing = game.chapter.dressing
	var checkpoint: Dictionary = game.saves._state.duplicate(true)
	var prefs: Dictionary = SettingsStore.default_accessibility()
	prefs.reduced_motion = true
	prefs.reduced_particles = true
	prefs.reduced_flashing = true
	game.settings.set_accessibility(prefs)
	await wait_process_frames(5)
	assert_false(art.is_processing())
	art._process(3.0)
	assert_eq(art.phase,0.0)
	for layer: Parallax2D in art._layers: assert_eq(layer.scroll_scale,Vector2.ZERO)
	for plant: Sprite2D in art._plants: assert_eq(plant.skew,0.0)
	for batch: MultiMeshInstance2D in art._snow: assert_false(batch.visible)
	for shaft: Sprite2D in art._shafts: assert_false(shaft.visible)
	assert_eq(game.saves._state,checkpoint)
	game.settings.set_accessibility(SettingsStore.default_accessibility())
	await wait_process_frames(5)
	assert_eq(art._layers[0].scroll_scale,Vector2(0.16,0.10))
	assert_eq(art._layers[1].scroll_scale,Vector2(0.42,0.25))
	for batch: MultiMeshInstance2D in art._snow: assert_true(batch.visible)

func test_clipped_painted_edges_stay_in_actual_stone_and_excavation_removes_old_trim() -> void:
	var paint: SunlitRockDressing = game.chapter.dressing.rocks
	assert_gt(paint.get_child_count(),5)
	for node: Node in paint.get_children():
		var polygon: Polygon2D = node as Polygon2D
		assert_not_null(polygon.texture)
		# Rough clipped outlines can be concave: their vertex average is not necessarily
		# inside. Inset toward each triangle's interior instead of crossing a notch.
		var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(polygon.polygon)
		assert_false(triangles.is_empty())
		for index: int in range(0,triangles.size(),3):
			var points: PackedVector2Array = PackedVector2Array([polygon.polygon[triangles[index]],polygon.polygon[triangles[index+1]],polygon.polygon[triangles[index+2]]])
			for point: Vector2 in points:
				var local: Vector2 = polygon.position+point.lerp(_center(points),0.01)
				assert_true(paint.contains_stone(local),str(local))
	var old_changed: Array[Node] = []
	var old_unchanged: Array[Node] = []
	for item: Dictionary in paint._surfaces:
		var source: Node = item.source.get_ref()
		if source is DestructibleRock and source.rock_id=="central-shelf": old_changed.append_array(item.trims)
		elif source is DestructibleRock and source.rock_id=="ceiling": old_unchanged.append_array(item.trims)
	assert_gt(game.excavation.excavate(Vector2(1490,650),70),0)
	for old: Node in old_changed: assert_false(old.get_parent()==paint,"Changed trim is removed immediately.")
	for old: Node in old_unchanged: assert_eq(old.get_parent(),paint,"Unchanged trim is reused rather than clipped again.")
	await wait_process_frames(5)
	assert_false(paint.contains_stone(Vector2(1490,650)))
	assert_false(game.chapter.dressing._plants[5].visible,"Unsupported kelp vanishes when its actual support is excavated.")
	assert_gt(paint.get_child_count(),0)

func _center(points: PackedVector2Array) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for point: Vector2 in points: sum += point
	return sum/points.size()

func test_hidden_trim_defers_clipping_until_visible_and_reuses_built_pieces() -> void:
	var paint: SunlitRockDressing = SunlitRockDressing.new()
	game.region.add_child(paint)
	paint.configure(game.region,game.chapter.boundary)
	await wait_process_frames(2)
	assert_eq(paint.get_child_count(),0,"Hidden scenes do not build decorative meshes.")
	paint.set_active(true)
	await wait_process_frames(2)
	assert_gt(paint.get_child_count(),5)
	var first: Node = paint.get_child(0)
	paint.set_active(false)
	paint.set_active(true)
	await wait_process_frames(2)
	assert_eq(paint.get_child(0),first,"Reopening an unchanged scene reuses its trim.")
	paint.set_active(false)
	paint.queue_free()

func test_prototype_switch_restores_legacy_materials_and_hides_all_new_dressing() -> void:
	var art: SunlitDressing = game.chapter.dressing
	var rock: DestructibleRock = game.excavation._rocks["central-shelf"]
	var illustrated: Material = rock.material
	assert_false((game.region.get_node("Atmosphere") as CanvasItem).visible)
	for item: Dictionary in art._legacy_relief: assert_false((item.node.get_ref() as CanvasItem).visible)
	game.chapter._activate(false)
	assert_false(art.is_visible_in_tree())
	assert_ne(rock.material,illustrated)
	assert_true((game.region.get_node("Atmosphere") as CanvasItem).visible)
	for item: Dictionary in art._legacy_relief: assert_eq((item.node.get_ref() as CanvasItem).visible,bool(item.visible))
	for paint: CreaturePaint in art._fish: assert_false(paint.sunlit_art)
	game.chapter._activate(true)
	assert_eq(rock.material,illustrated)
	for paint: CreaturePaint in art._fish: assert_true(paint.sunlit_art)

func test_pause_and_restart_preserve_authored_placements_progress_and_particle_bound() -> void:
	var art: SunlitDressing = game.chapter.dressing
	assert_eq(art._snow[0].multimesh.instance_count,36)
	assert_eq(art._snow[1].multimesh.instance_count,36)
	var plants: Array[Vector2] = []
	for plant: Sprite2D in art._plants: plants.append(plant.position)
	var state: Dictionary = game.story.snapshot()
	art.set_simulating(false)
	var phase: float = art.phase
	art._process(1.0)
	assert_eq(art.phase,phase)
	game.restart_route()
	await wait_process_frames(5)
	var after: Array[Vector2] = []
	for plant: Sprite2D in art._plants: after.append(plant.position)
	assert_eq(after,plants)
	assert_eq(game.story.snapshot(),state)

func test_each_comfort_flag_is_independent_and_fish_motion_remains_presentation_only() -> void:
	var art: SunlitDressing = game.chapter.dressing
	for field: String in ["reduced_motion","reduced_flashing","reduced_particles"]:
		var prefs: Dictionary = SettingsStore.default_accessibility()
		prefs[field] = true
		game.settings.set_accessibility(prefs)
		await wait_process_frames(5)
		assert_eq(art._layers[0].scroll_scale==Vector2.ZERO,field=="reduced_motion")
		assert_eq(art._snow[0].visible,field!="reduced_particles")
		assert_eq(art._shafts[0].visible,field!="reduced_flashing")
	var fish: CreaturePaint = art._fish[0]
	var at: Vector2 = game.creature.position
	game.creature.velocity = Vector2(-40,12)
	fish._process(0.1)
	assert_eq(fish.scale.x,-1.0)
	assert_eq(game.creature.position,at)
	assert_eq(game.creature.velocity,Vector2(-40,12))
	assert_eq((game.creature.get_node("CollisionShape2D") as CollisionShape2D).shape.radius,game.creature.configuration.body_radius)

func test_cosmetic_clock_is_equivalent_at_30_60_120_steps() -> void:
	var art: SunlitDressing = game.chapter.dressing
	for frequency: int in [30,60,120]:
		art.phase = 0.0
		art._redraw_time = 0.0
		art.set_simulating(true)
		for unused: int in range(frequency): art._process(1.0/frequency)
		assert_almost_eq(art.phase,1.0,0.00001)
		assert_almost_eq(art._plants[0].skew,sin(0.35)*0.025,0.00001)
		assert_eq(art._plants[0].position,SunlitDressing.ROOTS[0]-Vector2(0,2))
