class_name ResearchTree
extends Resource
## Authored capability branches. Rank IDs are stable branch name + 1-based rank.
@export var sonar_radii: PackedFloat32Array = PackedFloat32Array([900,1200,1500,1800])
@export var hull_ratings: PackedFloat32Array = PackedFloat32Array([300,400,450,500])
@export var torpedo_accelerations: PackedFloat32Array = PackedFloat32Array([500,750,1000,1250])
@export var torpedo_radii: PackedFloat32Array = PackedFloat32Array([150,190,215,240])
@export var engine_accelerations: PackedFloat32Array = PackedFloat32Array([120,180,240,300])
@export var first_rank_cost: int = 2
@export var rank_cost: int = 3
@export var commissioning_points: int = 2
@export var survey_points: int = 1
@export var decoding_points: int = 1
func is_valid() -> bool:
	for values: PackedFloat32Array in [sonar_radii,hull_ratings,torpedo_accelerations,torpedo_radii,engine_accelerations]:
		if values.size()!=4: return false
		for index: int in range(values.size()):
			if not is_finite(values[index]) or values[index]<=0 or values[index]>10000: return false
			if index>0 and values[index]<=values[index-1]: return false
	return commissioning_points==2 and survey_points==1 and decoding_points==1 and first_rank_cost==2 and rank_cost==3 and torpedo_radii[3]<=240

func values(branch: String) -> PackedFloat32Array:
	match branch:
		"sonar": return sonar_radii
		"hull": return hull_ratings
		"torpedo_acceleration": return torpedo_accelerations
		"torpedo_area": return torpedo_radii
		"engine": return engine_accelerations
	return PackedFloat32Array()

const TITLES: Dictionary = {"sonar":"ACOUSTIC ARRAY","hull":"PRESSURE HULL","torpedo_acceleration":"TORPEDO DRIVE","torpedo_area":"TORPEDO WARHEAD","engine":"MAIN ENGINES"}
const ICONS: Dictionary = {"sonar":preload("res://assets/art/upgrades/sonar.svg"),"hull":preload("res://assets/art/upgrades/hull.svg"),"torpedo_acceleration":preload("res://assets/art/upgrades/torpedo_acceleration.svg"),"torpedo_area":preload("res://assets/art/upgrades/torpedo_area.svg"),"engine":preload("res://assets/art/upgrades/engine.svg")}
func comparison(branch: String,rank: int,hull_baseline_bonus: float = 0.0,sonar_bonus: float = 0.0) -> String:
	var levels: PackedFloat32Array = values(branch)
	var next: int = mini(3,rank+1)
	if branch=="sonar" and sonar_bonus>0: return "Sonar range %.0f → %.0f units · delivery calibration included" % [levels[rank]+sonar_bonus,levels[next]+sonar_bonus]
	if branch=="hull": return "Rated depth %.0f → %.0f m" % [levels[rank]+hull_baseline_bonus,levels[next]+hull_baseline_bonus]
	var current: float = levels[rank]/levels[0]
	var upgraded: float = levels[next]/levels[0]
	if branch=="torpedo_area": return "Blast area %.2f× → %.2f× stock" % [current*current,upgraded*upgraded]
	return ("Sonar range" if branch=="sonar" else "Acceleration")+" %.2f× → %.2f× stock" % [current,upgraded]
