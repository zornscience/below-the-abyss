class_name CreaturePaint
extends Node2D
var phase: float = 0.0
var hostile: bool = false
var reduced_motion: bool = false
const FISH: Texture2D = preload("res://assets/art/sunlit/fish_atlas.png")
var sunlit_art: bool = false:
	set(value):
		sunlit_art = value
		queue_redraw()
var _redraw_time: float = 0.0
var _frames: Array[AtlasTexture] = []
var _swim: ShaderMaterial
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_swim = ShaderMaterial.new()
	_swim.shader = preload("res://assets/shaders/fauna_swim.gdshader")
	_swim.set_shader_parameter("cell",Vector4(0.5 if hostile else 0.0,0,0.5,1))
	for index: int in range(2):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = FISH
		atlas.region = Rect2(Vector2(FISH.get_width()*0.5*index,0),Vector2(FISH.get_width()*0.5,FISH.get_height()))
		_frames.append(atlas)
func _process(delta: float) -> void:
	var creature: AcousticCreature = get_parent() as AcousticCreature
	var previous: float = scale.x
	if not creature._suspended and not reduced_motion: phase += delta*4.0
	if absf(creature.velocity.x)>2: scale.x = signf(creature.velocity.x)
	material = _swim if sunlit_art else null
	_swim.set_shader_parameter("phase",phase)
	_swim.set_shader_parameter("amount",0.0 if reduced_motion else 1.0)
	_redraw_time += delta
	if not sunlit_art or previous!=scale.x or (_redraw_time>=1.0/15.0 and not reduced_motion and not creature._suspended):
		_redraw_time = 0.0
		queue_redraw()
func _draw() -> void:
	if sunlit_art and _frames.size()==2:
		draw_set_transform(Vector2.ZERO,0.0 if reduced_motion else sin(phase*0.5)*0.015)
		draw_texture_rect(_frames[1 if hostile else 0],Rect2(-44,-36,72,72),false)
		draw_set_transform(Vector2.ZERO)
		return
	var points: PackedVector2Array = []
	var colors: PackedColorArray = []
	for index: int in range(25):
		var angle: float = index*TAU/24.0
		points.append(Vector2(cos(angle)*25.0,sin(angle)*14.0))
		colors.append((Color("d4b88b") if hostile else Color("9cccbf")).lerp(Color("142e40"),(sin(angle)+1.0)*0.43))
	draw_polygon(points,colors)
	var fin: Color = Color("a3c7b2") if not hostile else Color("ba8f6c")
	draw_colored_polygon(PackedVector2Array([Vector2(-21,0),Vector2(-40,-15+sin(phase)*4),Vector2(-34,0),Vector2(-40,15+sin(phase)*4)]),fin.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(-9,-10),Vector2(0,-24),Vector2(15,-10)]),fin)
	draw_colored_polygon(PackedVector2Array([Vector2(0,5),Vector2(-8,21+sin(phase)*3),Vector2(15,8)]),fin.darkened(0.4))
	for index: int in range(5): draw_arc(Vector2(-10+index*5,0),6,-PI*0.4,PI*0.4,10,Color(0.7,0.92,0.85,0.22),1,true)
	draw_circle(Vector2(16,-3),4,Color("e5e4ae"))
	draw_circle(Vector2(17,-3),2.2,Color("0b1e2a"))
	for index: int in range(3): draw_circle(Vector2(-10+index*8,6),1.5,Color("b4e7d3"))
