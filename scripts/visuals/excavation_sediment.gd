class_name ExcavationSediment
extends Node2D
## Two bounded cosmetic batches; dust is soft alpha, fragments reuse the rock master.
## No bodies, no simulation writes. The guide advances this only while piloting.
var elapsed: float = 0.0
var reduced: bool = false
var _chips: MultiMeshInstance2D
var _cloud: MultiMeshInstance2D
static var _dust_mask: GradientTexture2D

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if _dust_mask==null:
		_dust_mask = GradientTexture2D.new()
		_dust_mask.width = 64
		_dust_mask.height = 64
		_dust_mask.fill = GradientTexture2D.FILL_RADIAL
		_dust_mask.fill_from = Vector2(0.5,0.5)
		_dust_mask.fill_to = Vector2(1,0.5)
		var gradient: Gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0,0.35,1])
		gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,0.55),Color.TRANSPARENT])
		_dust_mask.gradient = gradient
	_chips = _batch(4 if reduced else 8,Vector2(15,10),preload("res://assets/art/sunlit/basalt_strata.png"))
	_cloud = _batch(2 if reduced else 10,Vector2(90,90),_dust_mask)
	_pose()

func _batch(count: int,size_value: Vector2,texture: Texture2D) -> MultiMeshInstance2D:
	var batch: MultiMeshInstance2D = MultiMeshInstance2D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_2D
	batch.multimesh.use_colors = true
	var quad: QuadMesh = QuadMesh.new()
	quad.size = size_value
	batch.multimesh.mesh = quad
	batch.multimesh.instance_count = count
	batch.texture = texture
	add_child(batch)
	return batch

func _pose() -> void:
	var time: float = 0.0 if reduced else elapsed
	var fade: float = maxf(0,1.0-elapsed/4.0)
	for index: int in range(_chips.multimesh.instance_count):
		var at: Vector2 = Vector2(sin(index*2.41)*(12+time*35),-12-time*18+time*time*(16+index%3*4))
		_chips.multimesh.set_instance_transform_2d(index,Transform2D(index*0.7+time*0.8,Vector2.ONE*(0.5+index%3*0.2),0,at))
		_chips.multimesh.set_instance_color(index,Color(0.57,0.64,0.54,fade*0.7))
	for index: int in range(_cloud.multimesh.instance_count):
		var at: Vector2 = Vector2(sin(index*2.41)*(15+time*22),cos(index*1.71)*26+time*7)
		_cloud.multimesh.set_instance_transform_2d(index,Transform2D(0,Vector2.ONE*(0.75+time*0.7),0,at))
		_cloud.multimesh.set_instance_color(index,Color(0.55,0.62,0.50,fade*0.20))

func advance(delta: float) -> void:
	elapsed += delta
	if elapsed>=4: queue_free()
	else: _pose()
