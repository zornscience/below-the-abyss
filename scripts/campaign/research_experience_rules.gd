class_name ResearchExperienceRules
extends Resource
## Authored first-record awards. No per-instance fish IDs or persistent numeric totals.
@export var species_xp: int = 20
@export var study_xp: int = 30
@export var xp_per_point: int = 100
@export var maximum_extra_points: int = 2
@export var species_ids: Array[StringName] = []
@export var study_ids: Array[StringName] = []

func is_valid() -> bool:
	if species_xp<=0 or study_xp<=0 or xp_per_point<=0 or maximum_extra_points not in [0,1,2]: return false
	if species_xp>1000 or study_xp>1000 or xp_per_point>10000 or species_ids.size()+study_ids.size()>64: return false
	var seen: Array[StringName] = []
	for id: StringName in species_ids+study_ids:
		if not PointOfInterest.valid_id(id) or id in seen: return false
		seen.append(id)
	return not seen.is_empty()

func award_for(id: StringName) -> int:
	return species_xp if id in species_ids else (study_xp if id in study_ids else 0)
