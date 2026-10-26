class_name ExpeditionSchema
extends RefCounted
## Pure validation/migration. No node restoration or executable data from disk.

const VERSION: int = 2
const REGION: String = "continental_shelf"
const DISCOVERIES: DiscoveryCatalog = preload("res://resources/regions/shelf_discoveries.tres")
const RESEARCH: ResearchCatalog = preload("res://resources/regions/shelf_research.tres")
const UPGRADES: UpgradeCatalog = preload("res://resources/equipment/shelf_upgrades.tres")
const MISSIONS: MissionCatalog = preload("res://resources/missions/shelf_missions.tres")
const POOLS: SubmarineResourceConfig = preload("res://resources/balance/prototype_resources.tres")


static func number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum


static func ids(values: Variant, allowed: Array[StringName]) -> bool:
	if not values is Array or values.size() > allowed.size():
		return false
	var seen: Array[String] = []
	for value: Variant in values:
		if not value is String or StringName(value) not in allowed or value in seen:
			return false
		seen.append(value)
	return true


static func valid_progress(progress: Variant) -> bool:
	if not progress is Dictionary or progress.size() != 4:
		return false
	var discoveries: Array[StringName] = []
	for point: Resource in DISCOVERIES.points:
		discoveries.append(point.stable_id)
	var research: Array[StringName] = []
	for target: Resource in RESEARCH.targets:
		research.append(target.stable_id)
	var upgrades: Array[StringName] = []
	for definition: Resource in UPGRADES.upgrades:
		upgrades.append(definition.stable_id)
	return ids(progress.get("discoveries"), discoveries) and ids(progress.get("research"), research) \
		and ids(progress.get("upgrades"), upgrades) and progress.get("missions") is Dictionary \
		and MISSIONS.valid_records(progress.missions)


static func decode(value: Variant) -> Dictionary:
	if not value is Dictionary or not InputBindings.is_integer(value.get("schema_version")):
		return {"error": ERR_INVALID_DATA}
	var version: int = int(value.schema_version)
	if version not in [1, VERSION]:
		return {"error": ERR_UNAVAILABLE}
	var data: Dictionary = value.duplicate(true)
	if data.size() != 7 or not data.get("format") is String or data.format != "bta-expedition" or not data.get("region_id") is String or data.region_id != REGION \
		or not data.get("legacy_imported") is bool or data.legacy_imported != true or not data.get("player") is Dictionary \
		or not data.get("route") is Dictionary or not valid_progress(data.get("progress")):
		return {"error": ERR_INVALID_DATA}
	data.schema_version = VERSION
	var player: Dictionary = data.player
	if version == 1:
		if player.size() != 4:
			return {"error": ERR_INVALID_DATA}
		player.rotation = 0.0
		player.sonar_cooldown = 0.0
		data.schema_version = VERSION
	if player.size() != 6 or not player.get("position") is Array or player.position.size() != 2 \
		or not number(player.position[0], -1000000, 1000000) or not number(player.position[1], -1000000, 1000000) \
		or not number(player.get("rotation"), -PI, PI) or not number(player.get("hull"), 0, POOLS.max_hull) \
		or not number(player.get("battery"), 0, POOLS.max_battery) or not number(player.get("oxygen"), 0, POOLS.max_oxygen) \
		or not number(player.get("sonar_cooldown"), 0, 4.0):
		return {"error": ERR_INVALID_DATA}
	if data.route.size() != 2 or not InputBindings.is_integer(data.route.get("stage")) \
		or int(data.route.stage) not in [0, 1, 2, 3] or not number(data.route.get("elapsed_seconds"), 0, 360000):
		return {"error": ERR_INVALID_DATA}
	return {"error": OK, "data": data, "migrated": version != VERSION}


static func merge_progress(a: Dictionary, b: Dictionary) -> Dictionary:
	var merged: Dictionary = a.duplicate(true)
	for key: String in ["discoveries", "research", "upgrades"]:
		for id: Variant in b[key]:
			if String(id) not in merged[key]:
				merged[key].append(String(id))
		merged[key].sort()
	merged.missions = MISSIONS.merge_records(a.missions, b.missions)
	return merged
