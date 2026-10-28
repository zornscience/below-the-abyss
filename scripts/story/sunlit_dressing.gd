class_name SunlitDressing
extends Node2D
## Scene-owned canonical presentation. No movement, acoustic, progression or save writes.
const KELP: Texture2D = preload("res://assets/art/sunlit/kelp_atlas.png")
const PANORAMA: Texture2D = preload("res://assets/art/sunlit/shelf_panorama.png")
const CRADLE: Texture2D = preload("res://assets/art/sunlit/service_cradle.png")
const ROOTS: Array[Vector2] = [Vector2(740,800),Vector2(820,800),Vector2(940,800),
	Vector2(1110,695),Vector2(1260,630),Vector2(1490,630),Vector2(1600,630),Vector2(1800,630),
	Vector2(1940,630),Vector2(2120,632),Vector2(2300,650),Vector2(2460,656),Vector2(2680,667),
	Vector2(2825,735),Vector2(2950,800),Vector2(3080,800),Vector2(3200,800),Vector2(3340,800),
	Vector2(3510,800),Vector2(3590,800),Vector2(3710,740),Vector2(3800,800)]
var rocks: SunlitRockDressing
var phase: float = 0.0
var reduced_motion: bool = false
var reduced_effects: bool = false
var reduced_particles: bool = false
var _legacy_atmosphere: CanvasItem
var _legacy_visible: bool
var _legacy_relief: Array[Dictionary] = []
var _fish: Array[CreaturePaint] = []
var _plants: Array[Sprite2D] = []
var _layers: Array[Parallax2D] = []
var _shafts: Array[Sprite2D] = []
var _snow: Array[MultiMeshInstance2D] = []
var _redraw_time: float = 0.0
var _simulating: bool = false
var _configured: bool = false
var _composed: bool = false
var _camera: Camera2D

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	visibility_changed.connect(_visibility)

func configure(region: Node2D,boundary: Node2D,animals: Array[AcousticCreature]) -> void:
	_camera = region.get_viewport().get_camera_2d()
	_legacy_atmosphere = region.get_node("Atmosphere") as CanvasItem
	_legacy_visible = _legacy_atmosphere.visible
	for child: Node in region.get_children():
		if child is SeascapeRelief or child is BenthicGarden:
			_legacy_relief.append({"node":weakref(child),"visible":(child as CanvasItem).visible})
	rocks = SunlitRockDressing.new()
	rocks.name = "PaintedRockEdges"
	rocks.z_index = 3
	add_child(rocks)
	rocks.configure(region,boundary)
	for animal: AcousticCreature in animals:
		for child: Node in animal.get_children():
			if child is CreaturePaint: _fish.append(child)
	_configured = true
	_visibility()

func _compose() -> void:
	_composed = true
	_backgrounds()
	var roots: Array[Vector2] = ROOTS.duplicate()
	for x: int in range(4100,21800,260): roots.append(Vector2(x,800))
	roots.append_array([Vector2(6400,430),Vector2(7750,500),Vector2(9300,500),Vector2(10600,380),Vector2(12700,570),Vector2(15700,510),Vector2(17900,450)])
	for index: int in range(roots.size()):
		var plant: Sprite2D = Sprite2D.new()
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = KELP
		var species: int = index%4
		var upper: bool = species<2
		atlas.region = Rect2(Vector2(float(species%2)*0.5,0.0 if upper else 0.56)*KELP.get_size(),Vector2(0.5,0.56 if upper else 0.44)*KELP.get_size())
		plant.texture = atlas
		plant.centered = false
		var anchor_x: float = 0.55 if species==0 else (0.62 if species==1 else 0.5)
		if index%3==1: anchor_x = 1.0-anchor_x
		plant.offset = -Vector2(atlas.get_width()*anchor_x,atlas.get_height()*(0.96 if upper else 0.94))
		plant.position = roots[index]-Vector2(0,2)
		var height: float = 60.0+float((index*23)%80)
		if index in [4,5,6,7,8,18,19,20]: height *= 0.65
		plant.scale = Vector2.ONE*height/atlas.get_height()
		plant.flip_h = index%3==1
		plant.modulate = Color(0.59,0.79,0.73,0.92)
		plant.z_index = 1
		plant.set_meta("authored_root",roots[index])
		add_child(plant)
		_plants.append(plant)
	var cradle: Sprite2D = _sprite(CRADLE,Rect2(180,414,480,320),Color(0.85,0.93,0.90))
	cradle.name = "HalcyonServiceCradle"
	cradle.z_index = 3
	_make_snow(36,false)
	_make_snow(4,true)
	_make_snow(8,false)
	_snow.back().set_meta("vent",true)
	var vent_light: Sprite2D = _sprite(HalcyonDescent.SEARCHLIGHT,Rect2(-30,-190,1500,380),Color(0.86,0.47,0.20,0.16))
	vent_light.position = Vector2(14000,2470)
	vent_light.rotation = -PI*0.5
	vent_light.z_index = -3
	_shafts.append(vent_light)
	_refresh_plants.call_deferred()
	apply_preferences({"reduced_motion":reduced_motion,"reduced_flashing":reduced_effects,"reduced_particles":reduced_particles})

func _sprite(texture: Texture2D,rectangle: Rect2,tint: Color,parent: Node = null) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = rectangle.position
	sprite.scale = rectangle.size/texture.get_size()
	sprite.modulate = tint
	(self if parent==null else parent).add_child(sprite)
	return sprite

func _backgrounds() -> void:
	var far: Parallax2D = _layer(Vector2(0.16,0.10),-6)
	_sprite(PANORAMA,Rect2(-1400,-750,7000,1500),Color(0.24,0.40,0.44,0.35),far)
	var middle: Parallax2D = _layer(Vector2(0.42,0.25),-4)
	for index: int in range(10):
		var relief: Sprite2D = _sprite(HalcyonDescent.CLIFF,Rect2(-600+index*1100,-120,650,1150),Color(0.38,0.65,0.66,0.13),middle)
		var edge: ShaderMaterial = ShaderMaterial.new()
		edge.shader = preload("res://assets/shaders/sunlit_relief.gdshader")
		relief.material = edge
	for x: int in [450,1150,2050,2900,3500,5600,7400,9400,11000,12800,15400,17700,20400]:
		var shaft: Sprite2D = _sprite(HalcyonDescent.SEARCHLIGHT,Rect2(-30,-100,900,200),Color(0.76,0.87,0.75,0.045))
		shaft.position = Vector2(x,100)
		shaft.rotation = PI*0.5+0.12
		shaft.z_index = -3
		_shafts.append(shaft)

func _layer(scroll: Vector2,depth: int) -> Parallax2D:
	var layer: Parallax2D = Parallax2D.new()
	layer.scroll_scale = scroll
	layer.set_meta("a11y_scroll_scale",scroll)
	layer.z_index = depth
	add_child(layer)
	_layers.append(layer)
	return layer

func _make_snow(count: int,bubble: bool) -> void:
	var batch: MultiMeshInstance2D = MultiMeshInstance2D.new()
	batch.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var geometry: MultiMesh = MultiMesh.new()
	geometry.transform_format = MultiMesh.TRANSFORM_2D
	geometry.use_colors = true
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE*(5.0 if bubble else 3.0)
	geometry.mesh = quad
	geometry.instance_count = count
	batch.multimesh = geometry
	var mask: GradientTexture2D = GradientTexture2D.new()
	mask.width = 32
	mask.height = 32
	mask.fill = GradientTexture2D.FILL_RADIAL
	mask.fill_from = Vector2(0.5,0.5)
	mask.fill_to = Vector2(1,0.5)
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0,0.6,0.78,1]) if bubble else PackedFloat32Array([0,1])
	gradient.colors = PackedColorArray([Color.TRANSPARENT,Color.TRANSPARENT,Color.WHITE,Color.TRANSPARENT]) if bubble else PackedColorArray([Color.WHITE,Color.TRANSPARENT])
	mask.gradient = gradient
	batch.texture = mask
	batch.z_index = 2
	batch.set_meta("bubble",bubble)
	add_child(batch)
	_snow.append(batch)
	_position_snow()

func _position_snow() -> void:
	var left: float = floorf(to_local(_camera.global_position).x/1024.0)*1024.0-1024.0 if is_instance_valid(_camera) else -1024.0
	for batch: MultiMeshInstance2D in _snow:
		var bubble: bool = batch.get_meta("bubble")
		for index: int in range(batch.multimesh.instance_count):
			var at: Vector2 = Vector2(left+fposmod(index*137.731+phase*0.7,3072),200+fposmod(index*97.33+phase*(-5 if bubble else 1.3),560))
			if bool(batch.get_meta("vent",false)): at = Vector2(14000+sin(index*2.3+phase*0.4)*110,920+fposmod(index*137.0-phase*8,1450))
			batch.multimesh.set_instance_transform_2d(index,Transform2D(0,Vector2.ONE*(0.6+float(index%3)*0.2),0,at))
			batch.multimesh.set_instance_color(index,Color(0.83,0.49,0.23,0.25) if bool(batch.get_meta("vent",false)) else Color(0.62,0.83,0.81,0.28 if bubble else 0.21))

func set_simulating(value: bool) -> void:
	_simulating = value
	_update_process()

func _visibility() -> void:
	var active: bool = is_visible_in_tree()
	if rocks!=null: rocks.set_active(active)
	if active and _configured and not _composed: _compose()
	if active and rocks!=null: _refresh_plants.call_deferred()
	if is_instance_valid(_legacy_atmosphere): _legacy_atmosphere.visible = false if active else _legacy_visible
	for item: Dictionary in _legacy_relief:
		var canvas: CanvasItem = item.node.get_ref() as CanvasItem
		if is_instance_valid(canvas): canvas.visible = false if active else item.visible
	for fish: CreaturePaint in _fish:
		if is_instance_valid(fish): fish.sunlit_art = active
	_update_process()

func apply_preferences(value: Dictionary) -> void:
	reduced_motion = bool(value.reduced_motion)
	reduced_effects = bool(value.reduced_flashing)
	reduced_particles = bool(value.reduced_particles)
	if reduced_motion: phase = 0.0
	for layer: Parallax2D in _layers: layer.scroll_scale = Vector2.ZERO if reduced_motion else layer.get_meta("a11y_scroll_scale") as Vector2
	for shaft: Sprite2D in _shafts: shaft.visible = not reduced_effects
	for batch: MultiMeshInstance2D in _snow: batch.visible = not reduced_particles
	_pose_plants()
	_position_snow()
	_update_process()

func refresh_surfaces() -> void:
	if rocks==null: return
	rocks.refresh()
	_refresh_plants.call_deferred()

func _refresh_plants() -> void:
	for plant: Sprite2D in _plants:
		var at: Vector2 = plant.get_meta("authored_root")
		plant.visible = rocks.contains_stone(at+Vector2(0,5)) and not rocks.contains_stone(at-Vector2(0,8))

func _update_process() -> void:
	set_process(is_visible_in_tree() and _simulating and not reduced_motion)

func _pose_plants() -> void:
	for index: int in range(_plants.size()): _plants[index].skew = sin(phase*0.35+index*1.7)*0.025 if not reduced_motion else 0.0

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not _simulating or reduced_motion: return
	phase = fmod(phase+delta,1200.0)
	_redraw_time += delta
	if _redraw_time>=1.0/15.0:
		_redraw_time = fmod(_redraw_time,1.0/15.0)
		_pose_plants()
		_position_snow()
