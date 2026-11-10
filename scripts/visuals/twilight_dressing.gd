class_name TwilightDressing
extends Node2D
## Static illustrated environment over the exact BTA-053 collision contours.
const ATLAS: Texture2D = preload("res://assets/art/twilight/environment_atlas.png")
const CELLS: Array[Rect2] = [Rect2(0,0,610,724),Rect2(610,0,940,724),Rect2(1550,0,622,724)]
var rocks: SunlitRockDressing
var game: ShelfPrototype
var layout: TwilightShelfLayout
var enabled: bool = false
var _composed: bool = false
var _layers: Array[Sprite2D] = []
var _snow: MultiMeshInstance2D
var _phase: float = 0.0
var _redraw: float = 0.0
func setup(scene: ShelfPrototype,world: TwilightShelfLayout) -> void:
	game = scene
	layout = world
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	game.settings.settings_changed.connect(_preferences)
func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	if value and not _composed: _compose()
	if rocks!=null: rocks.set_active(value)
	_preferences()
func _sprite(cell: int,at: Vector2,width: float,tint: Color) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = ATLAS
	atlas.region = CELLS[cell]
	sprite.texture = atlas
	sprite.centered = false
	sprite.offset = Vector2(-atlas.get_width()*0.5,-atlas.get_height()*0.96)
	sprite.position = at
	sprite.scale = Vector2.ONE*width/atlas.get_width()
	sprite.modulate = tint
	add_child(sprite)
	return sprite
func _root(x: float,minimum: float = 1600) -> Vector2:
	for y: int in range(int(minimum),3901,4):
		for body: GrayboxRock in layout.bodies:
			if Geometry2D.is_point_in_polygon(Vector2(x,y+6),body.outline) and not Geometry2D.is_point_in_polygon(Vector2(x,y-10),body.outline): return Vector2(x,y)
	return Vector2(x,3900)
func _compose() -> void:
	_composed = true
	rocks = SunlitRockDressing.new()
	rocks.z_index = 2
	add_child(rocks)
	rocks.configure_geometry(layout.bodies,Rect2(TwilightShelfLayout.CAMERA))
	for index: int in range(10):
		var layer: Sprite2D = Sprite2D.new()
		layer.texture = preload("res://assets/art/painted/shelf_cliff.png")
		layer.position = Vector2(27200+index*1300,3100+index%3*270)
		layer.scale = Vector2(1.0,1.6)*1.2
		layer.flip_h = index%2==0
		layer.modulate = Color(0.18,0.32,0.39,0.23 if index%2==0 else 0.13)
		layer.z_index = -14+index%2
		layer.set_meta("anchor",layer.position)
		add_child(layer)
		_layers.append(layer)
	# A distant broken whaler silhouette, deliberately not Lantern-1 or a new objective.
	var wreck: Sprite2D = _sprite(1,_root(28900,3300),900,Color(0.42,0.58,0.64,0.85))
	wreck.offset.y = -724*0.88
	wreck.z_index = -5
	wreck.name = "HistoricWreckBackdrop"
	for index: int in range(42):
		var x: float = 27850+float((index*761)%10300)
		var plant: Sprite2D = _sprite(2,_root(x),90.0+float((index*31)%110),Color(0.44,0.69,0.73,0.95))
		plant.flip_h = index%2==0
		plant.z_index = 1
	for at: Vector2 in TwilightHabitat.VENT_SITES:
		_sprite(0,at,230,Color(0.70,0.78,0.81)).z_index = 1
	for profile: TunnelProfile in TwilightTunnelCatalog.DATA.systems:
		if not profile.vent_id.is_empty(): _sprite(0,profile.origin+profile.vent_at,230,Color(0.70,0.78,0.81)).z_index = 1
	# Sparse interrupted human cable, no perfect route line or hidden marker.
	for points: PackedVector2Array in [PackedVector2Array([Vector2(33150,1520),Vector2(33800,1610),Vector2(34600,1620),Vector2(35300,1630)]),PackedVector2Array([Vector2(35800,1800),Vector2(36050,2010),Vector2(36300,2030)])]:
		var cable: Line2D = Line2D.new()
		cable.points = points
		cable.width = 4
		cable.default_color = Color("7f877c")
		cable.antialiased = true
		add_child(cable)
	_make_snow()
func _make_snow() -> void:
	_snow = MultiMeshInstance2D.new()
	var mesh: MultiMesh = MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_2D
	mesh.use_colors = true
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(3,3)
	mesh.mesh = quad
	mesh.instance_count = 40
	_snow.multimesh = mesh
	var mask: GradientTexture2D = GradientTexture2D.new()
	mask.width = 16
	mask.height = 16
	mask.fill = GradientTexture2D.FILL_RADIAL
	mask.fill_from = Vector2(0.5,0.5)
	mask.fill_to = Vector2(1,0.5)
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE,Color.TRANSPARENT])
	mask.gradient = gradient
	_snow.texture = mask
	_snow.z_index = 4
	add_child(_snow)
	_pose()
func _preferences() -> void:
	if _snow==null: return
	_snow.visible = not game.settings.snapshot().accessibility.reduced_particles
	_pose()
func reset_session() -> void:
	_phase = 0
	_pose()
func advance(delta: float) -> void:
	if not enabled: return
	if not game.settings.snapshot().accessibility.reduced_motion: _phase = fmod(_phase+delta,1200)
	_redraw += delta
	if _redraw<1.0/15.0: return
	_redraw = 0
	_pose()
func _pose() -> void:
	if _snow==null: return
	var center: Vector2 = game.submarine.global_position
	var quiet: bool = game.settings.snapshot().accessibility.reduced_motion
	for index: int in range(_layers.size()):
		var sprite: Sprite2D = _layers[index]
		sprite.position = sprite.get_meta("anchor") as Vector2
		if not quiet: sprite.position += (center-TwilightShelfLayout.SPAWN)*Vector2(0.025,0.035)
	for index: int in range(40):
		var at: Vector2 = center+Vector2(fposmod(index*139.71+_phase*2,1600)-800,fposmod(index*97.33+_phase*3,1000)-500)
		_snow.multimesh.set_instance_transform_2d(index,Transform2D(0,at))
		_snow.multimesh.set_instance_color(index,Color(0.59,0.77,0.83,0.25))
