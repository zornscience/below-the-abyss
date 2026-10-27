extends GutTest
func _area(parts: Array[PackedVector2Array]) -> float:
	var area: float = 0.0
	for polygon: PackedVector2Array in parts:
		var sum: float = 0.0
		for index: int in range(polygon.size()): sum += polygon[index].cross(polygon[(index+1)%polygon.size()])
		area += absf(sum)*0.5
	return area
func test_expanded_authored_catalogs_are_valid_and_do_not_replace_legacy_records() -> void:
	assert_true(ShelfChapterData.discoveries().is_valid())
	assert_true(ShelfChapterData.research().is_valid())
	assert_true(ShelfChapterData.missions().is_valid())
	assert_true(ShelfChapterData.narrative().is_valid())
	var base: MissionCatalog = load("res://resources/missions/shelf_missions.tres") as MissionCatalog
	var old: Dictionary = base.initial_records()
	old["shelf-expedition"] = {"state":"claimed","objectives":["identify-spires","return-to-base"]}
	var migrated: Dictionary = ShelfChapterData.upgrade_missions(old)
	assert_eq(migrated["shelf-expedition"],old["shelf-expedition"])
	assert_eq(migrated["shelf-wreck-recovery"].state,"available")
	assert_eq(migrated.size(),5)
func test_battery_travel_window_and_sonar_relative_cost_are_authored() -> void:
	var profile: SubmarineResourceConfig = load("res://resources/balance/prototype_resources.tres") as SubmarineResourceConfig
	var pools: SubmarineResourceSystem = SubmarineResourceSystem.new()
	add_child_autofree(pools)
	pools.configure(profile)
	pools.advance(60.0,1.0)
	assert_almost_eq(pools.battery,98.2,0.0001)
	assert_gt(4.0,profile.battery_idle_drain_per_second+profile.battery_thrust_drain_per_second)
	assert_eq((load("res://resources/balance/prototype_sonar.tres") as ActiveSonarProfile).battery_cost,4.0)
	assert_gt(pools.oxygen,98.0)
func test_legacy_bindings_migrate_without_overwriting_custom_controls() -> void:
	var old: Dictionary = InputBindings.defaults()
	old.erase("fire_torpedo")
	old.sonar_ping = [{"kind":"key","code":KEY_SPACE},{"kind":"button","code":JOY_BUTTON_X}]
	var updated: Dictionary = InputBindings.compatible_bindings(old)
	assert_true(InputBindings.valid_bindings(updated))
	assert_eq(updated.sonar_ping,old.sonar_ping)
	assert_ne(updated.fire_torpedo[0].code,KEY_SPACE)
func test_optional_tutorial_preferences_validate_and_scoped_defaults_preserve_choice() -> void:
	var store: SettingsStore = SettingsStore.new()
	assert_eq(store.set_onboarding({"enabled":false,"seen":["movement","sonar"]}),OK)
	store.reset_input_defaults()
	assert_false(store.snapshot().onboarding.enabled)
	assert_eq(store.set_onboarding({"enabled":true,"seen":["movement","movement"]}),ERR_INVALID_PARAMETER)
	assert_eq(store.set_onboarding({"enabled":true,"seen":["unknown"]}),ERR_INVALID_PARAMETER)
func test_real_excavation_removes_solid_area_and_supports_an_internal_hole() -> void:
	var rock: DestructibleRock = DestructibleRock.new()
	add_child_autofree(rock)
	rock.configure("central-shelf",PackedVector2Array([Vector2(0,0),Vector2(500,0),Vector2(500,500),Vector2(0,500)]),Color.WHITE)
	assert_almost_eq(_area(rock.pieces),250000.0,0.01)
	assert_true(rock.carve(Vector2(250,250),100.0))
	assert_false(rock._inside(Vector2(250,250)))
	assert_true(rock._inside(Vector2(20,20)))
	assert_almost_eq(_area(rock.pieces),250000.0-PI*10000.0,250.0)
	var after: float = _area(rock.pieces)
	rock.carve(Vector2(250,250),100.0)
	assert_almost_eq(_area(rock.pieces),after,0.1)
	rock.reset_shape()
	assert_true(rock._inside(Vector2(250,250)))
func test_terrain_record_bounds_and_unknown_authored_ids_reject() -> void:
	assert_true(ExcavationState.valid([{"rock":"central-shelf","at":[1500,700],"radius":150.0}]))
	for bad: Variant in [[{"rock":"unknown","at":[10,10],"radius":100}], [{"rock":"central-shelf","at":[NAN,10],"radius":100}], [{"rock":"central-shelf","at":[10,10],"radius":5000}]]:
		assert_false(ExcavationState.valid(bad))
func test_legacy_completed_checkpoint_migrates_without_erasing_the_ending() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/expedition_v1.json"))
	var decoded: Dictionary = ExpeditionSchema.decode(raw)
	assert_eq(decoded.error,OK)
	assert_eq(decoded.data.schema_version,4)
	assert_eq(decoded.data.terrain,[])
	assert_true(decoded.data.has("legacy_conclusion"))
func test_completed_legacy_checkpoint_migrates_without_requiring_outer_missions() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/expedition_v1.json"))
	document.progress.missions["shelf-expedition"] = {"state":"claimed","objectives":["identify-spires","return-to-base"]}
	var decoded: Dictionary = ExpeditionSchema.decode(document)
	assert_eq(decoded.error,OK)
	assert_true(decoded.data.legacy_conclusion)
	assert_eq(decoded.data.terrain,[])
func test_malformed_terrain_and_conclusion_fields_are_rejected() -> void:
	var valid: Dictionary = ExpeditionSchema.decode(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/expedition_v1.json"))).data
	for invalid: Variant in [null,{},[{"rock":"unknown","at":[100,100],"radius":150}], [{"rock":"outer-bed","at":[true,100],"radius":150}]]:
		var document: Dictionary = valid.duplicate(true)
		document.terrain = invalid
		assert_eq(ExpeditionSchema.decode(document).error,ERR_INVALID_DATA)
	valid.legacy_conclusion = "true"
	assert_eq(ExpeditionSchema.decode(valid).error,ERR_INVALID_DATA)
