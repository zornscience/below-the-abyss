class_name SubmarineHeadlight
extends Node
## Nine cached rays light the first terrain surface. No shadows or screen readback.
var scene: ShelfPrototype
var _elapsed: float = 0.0
var _dirty: bool = true
var _origin: Vector2 = Vector2.INF
var _facing: Vector2 = Vector2.ZERO
var stops: PackedFloat32Array = []
func configure(game: ShelfPrototype) -> void:
	scene = game
	scene.excavation.geometry_changed.connect(func() -> void: _dirty = true)
func _physics_process(delta: float) -> void:
	if scene==null or scene.chapter==null: return
	if not scene.chapter.active and (scene.journey==null or not scene.journey.active()): return
	_elapsed += delta
	if _elapsed<0.05: return
	_elapsed = 0.0
	var origin: Vector2 = scene.submarine.global_position+scene.submarine.facing_direction()*20.0
	var facing: Vector2 = scene.submarine.facing_direction()
	if _dirty or origin.distance_squared_to(_origin)>1.0 or facing!=_facing:
		_origin = origin
		_facing = facing
		_dirty = false
		stops.clear()
		for index: int in range(9):
			var direction: Vector2 = facing.rotated(atan(lerpf(-0.22,0.22,index/8.0)))
			var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origin,origin+direction*600.0,1)
			query.hit_from_inside = true
			var hit: Dictionary = scene.submarine.get_world_2d().direct_space_state.intersect_ray(query)
			stops.append(origin.distance_to(hit.position) if not hit.is_empty() else 600.0)
	var quiet: bool = scene.settings.accessibility_flag(&"reduced_flashing")
	scene.chapter.dressing.rocks.set_headlight(origin,facing,stops,0.38 if quiet else 0.68)
	if scene.journey!=null and scene.journey.active() and scene.journey.habitat.dressing.rocks!=null:
		scene.journey.habitat.dressing.rocks.set_headlight(origin,facing,stops,0.38 if quiet else 0.68)
	var illustration: Node2D = scene.submarine.get_node("Visual") as Node2D
	if illustration!=null: illustration.set("beam_length",clampf(stops[4],20.0,500.0))
