class_name MissionCatalog
extends Resource

@export var stable_id: StringName = &"shelf-prototype"
@export var missions: Array[MissionDefinition] = []


func is_valid() -> bool:
	if not PointOfInterest.valid_id(stable_id) or missions.is_empty() or missions.size() > 16:
		return false
	var ids: Array[StringName] = []
	var rewards: Array[StringName] = []
	for definition: MissionDefinition in missions:
		if definition == null or not definition.is_valid() or definition.stable_id in ids or definition.acknowledgement_id in rewards:
			return false
		ids.append(definition.stable_id)
		rewards.append(definition.acknowledgement_id)
	return true


func definition(id: StringName) -> MissionDefinition:
	for mission: MissionDefinition in missions:
		if mission.stable_id == id:
			return mission
	return null


func initial_records() -> Dictionary:
	var records: Dictionary = {}
	for mission: MissionDefinition in missions:
		records[String(mission.stable_id)] = {"state": "available", "objectives": []}
	return records


func valid_records(records: Dictionary) -> bool:
	if records.size() != missions.size():
		return false
	for mission: MissionDefinition in missions:
		var record: Variant = records.get(String(mission.stable_id))
		if not record is Dictionary or record.size() != 2 or record.get("state") not in ["available", "accepted", "completed", "claimed"] \
			or not record.get("objectives") is Array or record.objectives.size() > mission.objectives.size():
			return false
		var seen: Array[String] = []
		for id: Variant in record.objectives:
			if not id is String or id in seen:
				return false
			var known: bool = false
			for objective: MissionObjective in mission.objectives:
				known = known or String(objective.stable_id) == id
			if not known:
				return false
			seen.append(id)
		if record.state == "available" and not seen.is_empty():
			return false
		if (record.state in ["completed", "claimed"]) != (seen.size() == mission.objectives.size()):
			return false
	return true


func merge_records(a: Dictionary, b: Dictionary) -> Dictionary:
	# Only validated documents enter here. Recovery is monotonic, never unclaims.
	var result: Dictionary = a.duplicate(true)
	var ranks: Array[String] = ["available", "accepted", "completed", "claimed"]
	for id: String in result:
		for objective: String in b[id].objectives:
			if objective not in result[id].objectives:
				result[id].objectives.append(objective)
		var rank: int = maxi(ranks.find(result[id].state), ranks.find(b[id].state))
		if result[id].objectives.size() == definition(StringName(id)).objectives.size():
			rank = maxi(rank, 2)
		result[id].state = ranks[rank]
		result[id].objectives.sort()
	return result
