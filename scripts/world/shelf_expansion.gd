class_name ShelfExpansion
extends Node
var wildlife: Array[AcousticCreature] = []
var excavation: ExcavationSystem
func setup(region: ContinentalShelf, include_story: bool = false) -> ExcavationSystem:
	excavation = ExcavationSystem.new()
	region.add_child(excavation)
	region.camera_bounds = ShelfChapterData.BOUNDS
	(region.get_node("Water") as Polygon2D).polygon = PackedVector2Array([Vector2.ZERO,Vector2(24000,0),Vector2(24000,1800),Vector2(0,1800)])
	var terrain: Node = region.get_node("Terrain")
	var east: Node = terrain.get_node("EastBoundary")
	terrain.remove_child(east)
	east.free()
	for child: Node in terrain.get_children():
		if child is GrayboxRock:
			var id: String = String(child.name).to_snake_case().replace("_","-")
			if id in ShelfChapterData.terrain_ids():
				var original: GrayboxRock = child as GrayboxRock
				_add_rock(terrain,id,original.outline,Color("17353c"))
				terrain.remove_child(original)
				original.free()
	for data: Dictionary in ShelfChapterData.ROCKS:
		_add_rock(terrain,data.id,data.points,Color("18353b") if data.id != "wreck-soft-plug" else Color("3e5549"))
	# Protected bedrock keeps excavation inside the authored region and camera limits.
	for polygon: PackedVector2Array in [PackedVector2Array([Vector2(0,0),Vector2(24000,0),Vector2(24000,60),Vector2(0,60)]),PackedVector2Array([Vector2(0,1740),Vector2(24000,1740),Vector2(24000,1800),Vector2(0,1800)]),PackedVector2Array([Vector2(23940,0),Vector2(24000,0),Vector2(24000,1800),Vector2(23940,1800)])]:
		var rock: GrayboxRock = preload("res://scenes/props/graybox_rock.tscn").instantiate() as GrayboxRock
		rock.outline = polygon
		terrain.add_child(rock)
	for data: Dictionary in ShelfChapterData.POINTS:
		var target: SonarRevealTarget = preload("res://scenes/props/sonar_reveal_target.tscn").instantiate() as SonarRevealTarget
		target.target_id = StringName(data.echo)
		target.caption = data.title
		region.get_node("SonarTargets").add_child(target)
		target.position = data.at
	for index: int in range(3):
		var sound: AmbientSoundEmitter = AmbientSoundEmitter.new()
		sound.source_id = StringName("outer-source-"+str(index))
		sound.configuration = AmbientEmissionProfile.new()
		sound.configuration.range_units = 2400.0
		sound.configuration.interval_seconds = 12.0
		sound.configuration.classification = &"geological" if index == 1 else &"mechanical"
		var emitter: AcousticEmitter = AcousticEmitter.new()
		emitter.name = "AcousticEmitter"
		sound.add_child(emitter)
		region.get_node("AmbientField").add_child(sound)
		sound.position = ShelfChapterData.POINTS[index].at
	for index: int in range(2):
		var grazer: AcousticCreature = preload("res://scenes/creatures/acoustic_creature.tscn").instantiate() as AcousticCreature
		grazer.name = "OuterGrazer"+str(index)
		grazer.creature_id = StringName("outer-grazer-"+str(index))
		grazer.configuration = CreatureProfile.new()
		var origin: Vector2 = Vector2(7400,900) if index == 0 else Vector2(14200,1120)
		grazer.configuration.navigation_bounds = Rect2(origin-Vector2(240,130),Vector2(480,260))
		grazer.configuration.patrol_points = PackedVector2Array([origin+Vector2(-150,-50),origin+Vector2(150,-50),origin+Vector2(150,50),origin+Vector2(-150,50)])
		grazer.position = origin
		region.add_child(grazer)
		wildlife.append(grazer)
	if include_story:
		var bloom_echo: SonarRevealTarget = preload("res://scenes/props/sonar_reveal_target.tscn").instantiate() as SonarRevealTarget
		bloom_echo.target_id = &"zone1-light-bloom-echo"
		bloom_echo.caption = "Light-bloom plankton"
		bloom_echo.position = Vector2(1330,590)
		region.get_node("SonarTargets").add_child(bloom_echo)
		var buoy_echo: SonarRevealTarget = preload("res://scenes/props/sonar_reveal_target.tscn").instantiate() as SonarRevealTarget
		buoy_echo.target_id = SunlitShallowsData.ECHO
		buoy_echo.caption = "Emergency buoy"
		buoy_echo.position = Vector2(3500,620)
		region.get_node("SonarTargets").add_child(buoy_echo)
	var station_art: StationIllustration = StationIllustration.new()
	station_art.position = Vector2(180,250)
	station_art.size = Vector2(480,195)
	region.add_child(station_art)
	var wreck: ExpeditionWreck = ExpeditionWreck.new()
	wreck.name = "ExpeditionWreck"
	region.add_child(wreck)
	wreck.position = Vector2(21600,1445)
	var ink: OuterShelfInk = OuterShelfInk.new()
	region.add_child(ink)
	# Remove route instructions/numbered arrows from the playable world; retain the dev fixture separately.
	(region.get_node("Landmarks") as CanvasItem).hide()
	(region.get_node("LandmarkInk") as CanvasItem).hide()
	return excavation
func _add_rock(parent: Node,id: String,polygon: PackedVector2Array,tint: Color) -> void:
	var rock: DestructibleRock = DestructibleRock.new()
	parent.add_child(rock)
	rock.configure(id,polygon,tint)
	excavation.register(rock)
