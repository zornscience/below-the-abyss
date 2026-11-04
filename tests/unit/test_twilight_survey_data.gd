extends GutTest
func test_optional_records_are_valid_unique_and_not_new_mission_gates() -> void:
	assert_true(TwilightShelfData.research().is_valid())
	assert_true(TwilightShelfData.discoveries().is_valid())
	assert_eq(TwilightShelfData.RECORDS.size(),10)
	var mission: MissionDefinition = TwilightShelfData.missions().definition(TwilightShelfData.MISSION)
	assert_eq(mission.objectives.size(),6)
	for id: StringName in TwilightShelfData.OPTIONAL_SURVEY:
		assert_true(TwilightShelfData.knows(id))
		for objective: MissionObjective in mission.objectives: assert_ne(objective.target_id,id)
func test_subject_images_distinguish_living_contact_wood_instruments_and_thermal_material() -> void:
	assert_eq(TwilightShelfData.subject_texture(&"twilight-net-survey"),preload("res://assets/art/twilight/sentinel.png"))
	var wood: AtlasTexture = TwilightShelfData.subject_texture(&"twilight-whaler-marking") as AtlasTexture
	var instrument: AtlasTexture = TwilightShelfData.subject_texture(&"twilight-mara-log-one") as AtlasTexture
	var mineral: AtlasTexture = TwilightShelfData.subject_texture(&"twilight-thermal-crust") as AtlasTexture
	assert_ne(wood.region,instrument.region)
	assert_ne(mineral.region,instrument.region)
	for texture: AtlasTexture in [wood,instrument,mineral]:
		assert_true(Rect2(Vector2.ZERO,texture.atlas.get_size()).encloses(texture.region))
		assert_true(texture.filter_clip)
