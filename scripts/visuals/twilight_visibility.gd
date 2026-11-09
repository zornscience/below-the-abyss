class_name TwilightVisibility
extends Node
## One screen pass; cached collision outlines. Never changes gameplay eligibility.
var profile: TwilightVisibilityProfile = preload("res://resources/balance/twilight_visibility.tres")
var scene: ShelfPrototype
var veil: CanvasLayer
var edges: CanvasLayer
var contours: Node2D
var headlight: SubmarineHeadlight
var material: ShaderMaterial
var edge_material: ShaderMaterial
var status: Label
var pings: PackedVector4Array = PackedVector4Array()
var speeds: PackedFloat32Array = PackedFloat32Array()
var starts: PackedFloat64Array = PackedFloat64Array()
var shaders: Array[ShaderMaterial] = []
var slot: int = 0
var reduced: bool = false
var _active: bool = false
var _epoch: int = 0
var _last_time: float = 0.0
var _sample: float = 0.0
var _distance: float = INF
func setup(game: ShelfPrototype) -> Error:
	if not profile.is_valid(): return ERR_INVALID_PARAMETER
	scene = game
	for child: Node in scene.chapter.get_children():
		if child is SubmarineHeadlight: headlight = child as SubmarineHeadlight
	pings.resize(8)
	speeds.resize(8)
	starts.resize(8)
	material = ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/twilight_visibility.gdshader")
	edge_material = material.duplicate() as ShaderMaterial
	shaders = [material,edge_material]
	edge_material.set_shader_parameter("outline",true)
	veil = CanvasLayer.new()
	veil.layer = 1
	add_child(veil)
	var rect: ColorRect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.material = material
	veil.add_child(rect)
	edges = CanvasLayer.new()
	edges.layer = 2
	add_child(edges)
	contours = Node2D.new()
	edges.add_child(contours)
	for candidate: Node in scene.journey.layout.find_children("*","CollisionPolygon2D",true,false):
		var boundary: CollisionPolygon2D = candidate as CollisionPolygon2D
		if not boundary.get_parent() is StaticBody2D: continue
		var line: Line2D = Line2D.new()
		line.points = boundary.polygon
		line.transform = scene.journey.layout.global_transform.affine_inverse()*boundary.global_transform
		line.closed = true
		line.width = 2.0
		line.material = edge_material
		contours.add_child(line)
	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.layer = 3
	add_child(hud_layer)
	status = Label.new()
	status.position = Vector2(16,190)
	UiTypography.style(status,&"secondary")
	hud_layer.add_child(status)
	_epoch = scene.submarine.sonar._epoch
	scene.submarine.sonar.state_changed.connect(_sonar_state_changed)
	scene.settings.settings_changed.connect(_preferences)
	scene.submarine.sonar.pulse_emitted.connect(_ping)
	scene.saves.checkpoint_restored.connect(clear_echoes)
	_preferences()
	return OK
func _preferences() -> void:
	var preferences: Dictionary = scene.settings.snapshot().accessibility
	UiTypography.apply(status,preferences.ui_scale)
	reduced = preferences.get("darkness","standard")=="reduced" or preferences.high_contrast
	for shader: ShaderMaterial in shaders:
		shader.set_shader_parameter("ambient",profile.reduced_ambient if reduced else profile.ambient)
		shader.set_shader_parameter("reduced",reduced)
		shader.set_shader_parameter("passive_radius",profile.passive_radius)
		shader.set_shader_parameter("safety_radius",profile.safety_radius*(1.3 if reduced else 1.0))
		shader.set_shader_parameter("light_range",profile.headlight_range)
		shader.set_shader_parameter("cone_angle",profile.cone_half_angle)
		shader.set_shader_parameter("echo_gain",profile.calm_echo_gain if preferences.reduced_flashing else profile.echo_gain)
		shader.set_shader_parameter("duration",profile.reveal_seconds)
func _sonar_state_changed() -> void:
	if _epoch!=scene.submarine.sonar._epoch:
		_epoch = scene.submarine.sonar._epoch
		clear_echoes()
func clear_echoes() -> void:
	for index: int in range(8): speeds[index] = 0
func _ping(event: AcousticEvent) -> void:
	if not scene.journey.active(): return
	pings[slot] = Vector4(event.origin.x,event.origin.y,0,event.range_units)
	starts[slot] = event.simulation_time
	speeds[slot] = scene.submarine.sonar.pulse_speed(event.event_id)
	slot = (slot+1)%8
func _process(delta: float) -> void:
	if scene==null: return
	_active = scene.journey.active() and (scene.get_node("WorldRoot") as Node2D).visible
	veil.visible = _active
	edges.visible = _active
	status.visible = _active
	if not _active: return
	if scene.submarine.sonar._time<_last_time: clear_echoes()
	_last_time = scene.submarine.sonar._time
	if scene.submarine.is_physics_processing():
		for index: int in range(8):
			if speeds[index]>0:
				pings[index].z = maxf(0,scene.submarine.sonar._time-starts[index])
				if pings[index].z>pings[index].w/speeds[index]+profile.reveal_seconds: speeds[index] = 0
	# Presentation samples the existing sonar simulation clock; pause freezes it.
	status.position = Vector2(16,scene.get_viewport().get_visible_rect().size.y-145)
	var canvas: Transform2D = scene.get_viewport().get_canvas_transform()
	contours.transform = canvas * scene.journey.layout.global_transform
	for shader: ShaderMaterial in shaders:
		var inverse: Transform2D = canvas.affine_inverse()
		shader.set_shader_parameter("screen_to_world",Transform3D(Basis(Vector3(inverse.x.x,inverse.x.y,0),Vector3(inverse.y.x,inverse.y.y,0),Vector3(0,0,1)),Vector3(inverse.origin.x,inverse.origin.y,0)))
		shader.set_shader_parameter("view_size",scene.get_viewport().get_visible_rect().size)
		shader.set_shader_parameter("vessel",scene.submarine.global_position)
		shader.set_shader_parameter("facing",scene.submarine.facing_direction())
		if headlight!=null and headlight.stops.size()==9: shader.set_shader_parameter("light_stops",headlight.stops)
		shader.set_shader_parameter("pings",pings)
		shader.set_shader_parameter("speeds",speeds)
	_sample += delta
	if _sample>=0.1:
		_sample = 0
		_distance = INF
		for index: int in range(16):
			var direction: Vector2 = Vector2.from_angle(TAU*index/16.0)
			var at: Vector2 = scene.submarine.global_position
			var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(at,at+direction*profile.safety_radius,1)
			var hit: Dictionary = scene.submarine.get_world_2d().direct_space_state.intersect_ray(query)
			if not hit.is_empty(): _distance = minf(_distance,at.distance_to(hit.position))
		status.text = ("CLOSE TERRAIN %.0f units" % _distance if is_finite(_distance) else "QUIET NAVIGATION · CLOSE CUE ON")+"\nVISION "+("REDUCED" if reduced else "STANDARD")+" · SONAR "+scene.submarine.sonar.status_text()
