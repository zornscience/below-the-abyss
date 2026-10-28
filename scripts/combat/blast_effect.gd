class_name BlastEffect
extends Node2D
## Local pressure flash, expanding/contracting cavitation, suspended debris and rising gas.
## Three bounded batches, no gameplay writes or secondary acoustic emissions.
var radius: float = 150.0
var elapsed: float = 0.0
var refractive: bool = false
var _lens: ColorRect
var reduced_effects: bool = false
var _cloud: MultiMeshInstance2D
var _bubbles: MultiMeshInstance2D
var _chips: MultiMeshInstance2D
static var _soft: GradientTexture2D
static var _ring: GradientTexture2D

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if reduced_effects: return
	if _soft==null:
		_soft = _mask(false)
		_ring = _mask(true)
	_cloud = _batch(10,_soft,Vector2(70,70))
	_bubbles = _batch(28,_ring,Vector2(12,12))
	_chips = _batch(12,preload("res://assets/art/sunlit/basalt_strata.png"),Vector2(9,6))
	_pose()
	if refractive:
		_lens = ColorRect.new()
		_lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lens.position = -Vector2.ONE*radius*2.0
		_lens.size = Vector2.ONE*radius*4.0
		var lens_material: ShaderMaterial = ShaderMaterial.new()
		lens_material.shader = preload("res://assets/shaders/impact_refraction.gdshader")
		_lens.material = lens_material
		add_child(_lens)

func _mask(ring: bool) -> GradientTexture2D:
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1,0.5)
	texture.gradient = Gradient.new()
	texture.gradient.offsets = PackedFloat32Array([0,0.58,0.8,1])
	texture.gradient.colors = PackedColorArray([Color.TRANSPARENT,Color.TRANSPARENT,Color.WHITE,Color.TRANSPARENT]) if ring else PackedColorArray([Color.WHITE,Color(1,1,1,0.7),Color(1,1,1,0.2),Color.TRANSPARENT])
	return texture

func _batch(count: int,texture: Texture2D,dimensions: Vector2) -> MultiMeshInstance2D:
	var batch: MultiMeshInstance2D = MultiMeshInstance2D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_2D
	batch.multimesh.use_colors = true
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = dimensions
	batch.multimesh.mesh = mesh
	batch.multimesh.instance_count = count
	batch.texture = texture
	add_child(batch)
	return batch

func _pose() -> void:
	if _cloud==null: return
	var fade: float = maxf(0,1-elapsed/2.6)
	var cavity: float = sin(clampf(elapsed/1.1,0,1)*PI)*radius*0.48
	for i: int in range(10):
		var angle: float = i*2.39996
		var at: Vector2 = Vector2.from_angle(angle)*(cavity+elapsed*16)-Vector2(0,elapsed*12)
		_cloud.multimesh.set_instance_transform_2d(i,Transform2D(angle,Vector2.ONE*(0.5+elapsed*0.7),0,at))
		_cloud.multimesh.set_instance_color(i,Color(0.63,0.83,0.80,fade*0.16))
	for i: int in range(28):
		var at: Vector2 = Vector2.from_angle(i*2.39996)*radius*(1-exp(-elapsed*2.8))*0.65
		at.y -= elapsed*elapsed*(16+i%5*4)
		at.x += sin(i+elapsed*3)*elapsed*5
		_bubbles.multimesh.set_instance_transform_2d(i,Transform2D(0,Vector2.ONE*(0.3+i%4*0.18),0,at))
		_bubbles.multimesh.set_instance_color(i,Color(0.73,0.92,0.94,fade*0.65))
	for i: int in range(12):
		var at: Vector2 = Vector2.from_angle(i*2.39996)*elapsed*55+Vector2(0,elapsed*elapsed*18)
		_chips.multimesh.set_instance_transform_2d(i,Transform2D(i+elapsed,Vector2.ONE*(0.45+i%3*0.3),0,at))
		_chips.multimesh.set_instance_color(i,Color(0.55,0.68,0.66,fade))

func advance(delta: float) -> void:
	elapsed += delta
	if _lens!=null:
		_lens.visible = elapsed<0.65 and not reduced_effects
		(_lens.material as ShaderMaterial).set_shader_parameter("phase",clampf(elapsed/0.65,0,1))
	if elapsed>=(0.65 if reduced_effects else 2.6): queue_free()
	if _cloud!=null:
		_cloud.visible = not reduced_effects
		_bubbles.visible = not reduced_effects
		_chips.visible = not reduced_effects
		_pose()
	queue_redraw()

func _draw() -> void:
	var t: float = clampf(elapsed/0.65,0,1)
	var fade: float = 1-t
	if elapsed<0.65:
		draw_arc(Vector2.ZERO,maxf(1,radius*sqrt(t)),0,TAU,64,Color(0.65,0.9,0.95,fade*0.7),3,true)
		if not reduced_effects:
			draw_circle(Vector2.ZERO,52*fade,Color(0.6,0.88,0.96,fade*0.16))
			draw_circle(Vector2.ZERO,24*fade,Color(0.96,0.98,0.86,fade*0.7))
			draw_circle(Vector2.ZERO,10*fade,Color(1,1,0.95,fade))
