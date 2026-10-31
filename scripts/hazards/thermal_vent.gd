class_name ThermalVent
extends Node2D
## Scene-owned reusable jet. Local chimney collision, no save file or dispatcher replacement.
signal damage_applied(amount: float)
@export var stable_id: StringName = &""
@export var configuration: ThermalVentProfile = preload("res://resources/hazards/twilight_vent.tres")
var model: ThermalVentState = ThermalVentState.new()
var _rules: ThermalVentProfile
var _game: ShelfPrototype
var _solid: StaticBody2D
var enabled: bool = false:
	set(value):
		enabled = value
		if _solid!=null: _solid.collision_layer = 1 if value else 0
var _plume: Sprite2D
var _visual_clock: float = 0.0
var _material: ShaderMaterial
func setup(game: ShelfPrototype) -> Error:
	if not PointOfInterest.valid_id(stable_id) or configuration==null or not configuration.is_valid(): return ERR_INVALID_PARAMETER
	_game = game
	_solid = StaticBody2D.new()
	_solid.collision_layer = 0
	_solid.collision_mask = 2
	var boundary: CollisionPolygon2D = CollisionPolygon2D.new()
	boundary.polygon = PackedVector2Array([Vector2(-108,-8),Vector2(-64,-75),Vector2(-63,-182),Vector2(-42,-260),Vector2(-24,-196),Vector2(-15,-89),Vector2(15,-58),Vector2(32,-115),Vector2(53,-164),Vector2(71,-115),Vector2(76,-45),Vector2(112,-8)])
	_solid.add_child(boundary)
	add_child(_solid)
	_rules = configuration.duplicate(true) as ThermalVentProfile
	model.configure(_rules)
	_plume = Sprite2D.new()
	_plume.texture = preload("res://assets/art/painted/searchlight.png")
	_plume.rotation = -PI*0.5
	_plume.position = _rules.plume.get_center()
	_plume.scale = Vector2(_rules.plume.size.y,_rules.plume.size.x*1.8)/_plume.texture.get_size()
	_material = ShaderMaterial.new()
	_material.shader = preload("res://assets/shaders/thermal_plume.gdshader")
	_plume.material = _material
	_plume.z_index = 2
	add_child(_plume)
	refresh_visuals()
	return OK
func exposes(at: Vector2,radius: float = 28.0) -> bool:
	# A conservative hull envelope. Terrain occlusion prevents damage through rock.
	if _rules==null or not at.is_finite() or not is_finite(radius) or radius<0: return false
	if not _rules.plume.grow(radius).has_point(to_local(at)): return false
	var origin: Vector2 = to_global(Vector2(_rules.plume.get_center().x,_rules.plume.end.y-8))
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origin,at,1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()
func danger_at(at: Vector2) -> bool:
	return enabled and model.phase() in [ThermalVentState.Phase.WARNING,ThermalVentState.Phase.ERUPTING] and exposes(at)
func prompt(at: Vector2) -> String:
	if not enabled or global_position.distance_to(at)>_rules.warning_radius: return ""
	match model.phase():
		ThermalVentState.Phase.WARNING: return "! THERMAL VENT · Eruption in %.1f s · Clear the rising jet" % model.seconds_to_eruption()
		ThermalVentState.Phase.ERUPTING: return "! THERMAL JET · Hull damage · Move around the plume"
		_: return "THERMAL VENT · Quiet window · Jet cycles periodically"
func advance(delta: float) -> void:
	if not is_finite(delta) or delta<0 or delta>1.0 or not enabled or not _game.submarine.is_physics_processing(): return
	var exposure: bool = exposes(_game.submarine.global_position)
	var amount: float = model.advance(delta,exposure)
	if amount>0:
		var removed: float = _game.submarine.hull_system.apply_damage(amount,StringName("thermal/"+String(stable_id)))
		if removed>0: damage_applied.emit(removed)
	var preferences: Dictionary = _game.settings.snapshot().accessibility
	if not preferences.reduced_motion: _visual_clock += delta
	refresh_visuals()
func reset_session() -> void:
	model.reset()
	_visual_clock = 0.0
	refresh_visuals()
func refresh_visuals() -> void:
	if _plume==null: return
	var preferences: Dictionary = _game.settings.snapshot().accessibility
	var erupting: bool = model.phase()==ThermalVentState.Phase.ERUPTING
	var warning: bool = model.phase()==ThermalVentState.Phase.WARNING
	_material.set_shader_parameter("phase",_visual_clock)
	_material.set_shader_parameter("calm",preferences.reduced_motion or preferences.reduced_flashing)
	_plume.visible = erupting or warning
	_plume.modulate = Color(1.0,0.56,0.23,0.55 if erupting else 0.18)
	if preferences.reduced_flashing: _plume.modulate = Color(0.8,0.7,0.5,0.3 if erupting else 0.12)
	_plume.skew = 0.0 if preferences.reduced_motion or preferences.reduced_flashing else sin(_visual_clock*2.0)*0.08
