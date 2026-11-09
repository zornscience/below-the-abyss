extends GutTest
func test_data_compiles_two_branched_systems_scaled_to_actual_vessel() -> void:
	var vessel: SubmarineController = preload("res://scenes/player/submarine.tscn").instantiate() as SubmarineController
	var shape: CapsuleShape2D = (vessel.get_node("CollisionShape2D") as CollisionShape2D).shape as CapsuleShape2D
	assert_eq(shape.height,64.0)
	assert_eq(shape.radius*2,32.0)
	var ids: Array[String] = []
	var indices: Array[int] = []
	assert_true(TwilightTunnelCatalog.is_valid(shape.height))
	assert_gte(TwilightTunnelCatalog.DATA.systems.size(),2)
	for profile: TunnelProfile in TwilightTunnelCatalog.DATA.systems:
		assert_true(profile.is_valid(shape.height),String(profile.stable_id))
		assert_false(profile.gate_id in ShelfChapterData.terrain_ids(),"Stable gates never replace a Sunlit registry entry")
		assert_false(profile.gate_id in ids)
		assert_false(profile.replace_index in indices)
		ids.append(profile.gate_id)
		indices.append(profile.replace_index)
		assert_gt(TunnelProfile.length(profile.long_path()),TunnelProfile.length(profile.shortcut))
		var pieces: Array[PackedVector2Array] = profile.rock_polygons()
		assert_gt(pieces.size(),0)
		for part: PackedVector2Array in pieces:
			assert_false(Geometry2D.triangulate_polygon(part).is_empty())
		print("TUNNEL_DATA ",profile.stable_id," pieces=",pieces.size()," long=",TunnelProfile.length(profile.long_path())," shortcut=",TunnelProfile.length(profile.shortcut))
	vessel.free()
func test_cut_validation_limits_twilight_coordinates_by_stable_gate_without_changing_old_bounds() -> void:
	for profile: TunnelProfile in TwilightTunnelCatalog.DATA.systems:
		var cut: Dictionary = {"rock":profile.gate_id,"at":[profile.world_gate().get_center().x,profile.world_gate().get_center().y],"radius":150.0}
		assert_true(ExcavationState.valid([cut]))
		cut.at = [0,0]
		assert_false(ExcavationState.valid([cut]))
		cut.rock = "unregistered-twilight-gate"
		assert_false(ExcavationState.valid([cut]))
	var old: String = ShelfChapterData.terrain_ids()[0]
	assert_true(ExcavationState.valid([{"rock":old,"at":[24000,1800],"radius":240}]))
	assert_false(ExcavationState.valid([{"rock":old,"at":[24001,1800],"radius":240}]))
func test_optional_payoffs_are_registered_but_do_not_change_research_economy() -> void:
	for item: Dictionary in TwilightTunnelCatalog.records():
		assert_false(item.id in ResearchExperienceData.TWILIGHT.study_ids)
		assert_false(item.id in ResearchExperienceData.RULES.study_ids)
		assert_true(TwilightShelfData.knows(StringName(item.id)))
		assert_eq(TwilightShelfData.record(StringName(item.id)).at,item.at)
		assert_true(TwilightShelfData.research().is_valid())
		for mission: MissionDefinition in TwilightShelfData.missions().missions:
			for objective: MissionObjective in mission.objectives: assert_ne(String(objective.target_id),item.id)
func test_one_gate_is_always_inside_and_one_always_outside_stalker_hearing() -> void:
	var rules: RiftStalkerProfile = TwilightHunt.PROFILE
	var territory: Rect2 = rules.navigation_bounds.grow(-rules.body_radius)
	var inside: int = 0
	var outside: int = 0
	var range_units: float = rules.hearing.maximum_range_units # Also checked against the real launcher in integration.
	for profile: TunnelProfile in TwilightTunnelCatalog.DATA.systems:
		var gate: Rect2 = profile.world_gate()
		var near: float = INF
		var far: float = 0
		for corner: Vector2 in [gate.position,gate.end,Vector2(gate.position.x,gate.end.y),Vector2(gate.end.x,gate.position.y)]:
			near = minf(near,corner.distance_to(corner.clamp(territory.position,territory.end)))
			for listener: Vector2 in [territory.position,territory.end,Vector2(territory.position.x,territory.end.y),Vector2(territory.end.x,territory.position.y)]: far = maxf(far,corner.distance_to(listener))
		if far<range_units: inside += 1
		if near>range_units: outside += 1
		print("TUNNEL_HEARING ",profile.gate_id," nearest=",near," farthest=",far)
	assert_gte(inside,1)
	assert_gte(outside,1)
