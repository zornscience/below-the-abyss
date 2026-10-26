extends GutTest

const CATALOG: DiscoveryCatalog = preload("res://resources/regions/shelf_discoveries.tres")
var _registry: DiscoveryRegistry


func before_each() -> void:
	_registry = DiscoveryRegistry.new()
	add_child_autofree(_registry)
	assert_eq(_registry.configure(CATALOG), OK)


func test_authored_ids_are_unique_stable_and_initially_hidden() -> void:
	assert_true(CATALOG.is_valid())
	assert_eq(_registry.region_id(), &"continental_shelf")
	assert_true(_registry.discovered_points().is_empty())
	var catalog: DiscoveryCatalog = CATALOG as DiscoveryCatalog
	for point: PointOfInterest in catalog.points:
		assert_eq(_registry.state_of(point.stable_id), DiscoveryRegistry.State.HIDDEN)
	assert_eq(_registry.configure(CATALOG), ERR_ALREADY_IN_USE)


func test_duplicate_discovery_is_idempotent_and_signals_once() -> void:
	watch_signals(_registry)
	assert_eq(_registry.discover(&"shelf-overlook", &"ping/1"), OK)
	assert_eq(_registry.discover(&"shelf-overlook", &"ping/1"), ERR_ALREADY_EXISTS)
	assert_eq(_registry.discover(&"shelf-overlook", &"ping/2"), ERR_ALREADY_EXISTS)
	assert_signal_emit_count(_registry, "point_discovered", 1)
	assert_eq(_registry.discovered_ids(), [&"shelf-overlook"])
	assert_eq(_registry.state_of(&"shelf-overlook"), DiscoveryRegistry.State.DISCOVERED)
	assert_eq(_registry.discover(&"unknown", &"ping/1"), ERR_INVALID_PARAMETER)
	assert_eq(_registry.discover(&"shelf-twin-spires", &""), ERR_INVALID_PARAMETER)


func test_catalog_rejects_duplicate_ids_targets_and_invalid_definitions() -> void:
	for field: String in ["stable_id", "sonar_target_id"]:
		var catalog: DiscoveryCatalog = CATALOG.duplicate(true) as DiscoveryCatalog
		catalog.points[1].set(field, catalog.points[0].get(field))
		assert_false(catalog.is_valid())
	for id: StringName in [&"", &"../path", &"UPPER", &"space id"]:
		assert_false(PointOfInterest.valid_id(id))
	var catalog: DiscoveryCatalog = CATALOG.duplicate(true) as DiscoveryCatalog
	catalog.points[0].map_position = Vector2(INF, 0)
	assert_false(catalog.is_valid())
	catalog.points[0].map_position = Vector2(-1, 0)
	assert_false(catalog.is_valid())
	catalog.points[0] = null
	assert_false(catalog.is_valid())


func test_restore_validates_entire_list_then_merges_without_erasing() -> void:
	assert_eq(_registry.discover(&"shelf-overlook", &"ping/1"), OK)
	assert_eq(_registry.restore_discoveries([&"shelf-navigation-marker", &"missing"]), ERR_INVALID_DATA)
	assert_eq(_registry.discovered_ids(), [&"shelf-overlook"])
	assert_eq(_registry.restore_discoveries([&"shelf-navigation-marker", &"shelf-navigation-marker"]), ERR_INVALID_DATA)
	assert_eq(_registry.restore_discoveries([&"shelf-navigation-marker"]), OK)
	assert_eq(_registry.restore_discoveries([]), OK)
	assert_eq(_registry.discovered_ids(), [&"shelf-navigation-marker", &"shelf-overlook"])


func test_authored_and_returned_resources_cannot_mutate_registry_metadata() -> void:
	var catalog: DiscoveryCatalog = CATALOG.duplicate(true) as DiscoveryCatalog
	var registry: DiscoveryRegistry = DiscoveryRegistry.new()
	add_child_autofree(registry)
	assert_eq(registry.configure(catalog), OK)
	catalog.points[0].stable_id = &"changed"
	assert_true(registry.knows_id(&"shelf-navigation-marker"))
	assert_eq(registry.discover(&"shelf-navigation-marker", &"ping/1"), OK)
	registry.discovered_points()[0].display_name = "Changed"
	assert_eq(registry.discovered_points()[0].display_name, "Shelf navigation marker")
