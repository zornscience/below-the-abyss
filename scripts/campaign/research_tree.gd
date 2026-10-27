class_name ResearchTree
extends Resource
## Two authored talent branches. Rank IDs are stable branch name + 1-based rank.
@export var sonar_radii: PackedFloat32Array = PackedFloat32Array([900,1200,1500,1800])
@export var hull_ratings: PackedFloat32Array = PackedFloat32Array([300,400,450,500])
@export var commissioning_points: int = 2
@export var survey_points: int = 1
@export var decoding_points: int = 1
func is_valid() -> bool:
	for values: PackedFloat32Array in [sonar_radii,hull_ratings]:
		if values.size()!=4: return false
		for index: int in range(values.size()):
			if not is_finite(values[index]) or values[index]<=0 or values[index]>10000: return false
			if index>0 and values[index]<=values[index-1]: return false
	return commissioning_points==2 and survey_points==1 and decoding_points==1
