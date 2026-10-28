class_name ExcavationSystem
extends Node
## Bounded, authored solid-rock registry. Terrain edits are replayed before vessel restore.
signal geometry_changed
var _rocks: Dictionary[String, DestructibleRock] = {}
var _cuts: Array[Dictionary] = []
func register(rock: DestructibleRock) -> void:
	assert(not _rocks.has(rock.rock_id))
	_rocks[rock.rock_id] = rock
func excavate(origin: Vector2, radius: float) -> int:
	if _cuts.size() >= ExcavationState.MAX_CUTS:
		return 0
	var changed: int = 0
	var keys: Array = _rocks.keys()
	keys.sort()
	for key: String in keys:
		if _cuts.size() >= ExcavationState.MAX_CUTS:
			break
		if _rocks[key].collision_layer!=0 and _rocks[key].carve(origin, radius):
			_cuts.append({"rock": key, "at": [origin.x, origin.y], "radius": radius})
			changed += 1
	if changed>0: geometry_changed.emit()
	return changed
func snapshot() -> Array[Dictionary]:
	return _cuts.duplicate(true)
func restore(records: Array) -> Error:
	if not ExcavationState.valid(records):
		return ERR_INVALID_DATA
	for rock: DestructibleRock in _rocks.values():
		rock.reset_shape()
	_cuts.clear()
	for cut: Dictionary in records:
		if _rocks.has(cut.rock):
			_rocks[cut.rock].carve(Vector2(cut.at[0],cut.at[1]), cut.radius)
			_cuts.append(cut.duplicate(true))
	geometry_changed.emit()
	return OK
