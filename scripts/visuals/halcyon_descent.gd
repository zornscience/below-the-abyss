class_name HalcyonDescent
extends Control
## Presentation clock only. No player, physics, input, random-stream or save access.
const VESSEL: Texture2D = preload("res://assets/art/painted/lantern_2.png")
const STATION: Texture2D = preload("res://assets/art/painted/halcyon_modules.png")
const WATER: Texture2D = preload("res://assets/art/painted/descent_water.png")
const CLIFF: Texture2D = preload("res://assets/art/painted/shelf_cliff.png")
const SEARCHLIGHT: Texture2D = preload("res://assets/art/painted/searchlight.png")
const PARTICLE_COUNT: int = 42
var phase: float = 0.0
var reduced_motion: bool = false
var reduced_effects: bool = false
var reduced_particles: bool = false
var _redraw_time: float = 0.0
var _water: TextureRect
var _cliffs: Array[TextureRect] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_water = TextureRect.new()
	_water.texture = WATER
	_water.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_water.stretch_mode = TextureRect.STRETCH_SCALE
	_water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_water.show_behind_parent = true
	_water.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var paint: ShaderMaterial = ShaderMaterial.new()
	paint.shader = preload("res://assets/shaders/title_water.gdshader")
	_water.material = paint
	add_child(_water)
	for index: int in range(3):
		var relief: TextureRect = TextureRect.new()
		relief.texture = CLIFF
		relief.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		relief.stretch_mode = TextureRect.STRETCH_SCALE
		relief.mouse_filter = Control.MOUSE_FILTER_IGNORE
		relief.show_behind_parent = true
		var edges: ShaderMaterial = ShaderMaterial.new()
		edges.shader = preload("res://assets/shaders/illustration_edge.gdshader")
		relief.material = edges
		add_child(relief)
		_cliffs.append(relief)
	_layout_relief()
	resized.connect(_layout_relief)
	resized.connect(queue_redraw)
	visibility_changed.connect(_visibility_changed)

func apply_preferences(value: Dictionary) -> void:
	reduced_motion = bool(value.reduced_motion)
	reduced_effects = bool(value.reduced_flashing)
	reduced_particles = bool(value.reduced_particles)
	# Use a stable authored pose for the static comfort alternative.
	if reduced_motion: phase = 0.0
	if _water!=null:
		(_water.material as ShaderMaterial).set_shader_parameter("motion_amount",0.0 if reduced_motion or reduced_effects else 1.0)
		(_water.material as ShaderMaterial).set_shader_parameter("phase",phase)
	set_process(not reduced_motion and is_visible_in_tree())
	_layout_relief()
	queue_redraw()

func _visibility_changed() -> void:
	set_process(not reduced_motion and is_visible_in_tree())

func _process(delta: float) -> void:
	if not is_visible_in_tree() or reduced_motion: return
	phase = fmod(phase+delta,1200.0)
	_redraw_time += delta
	if _redraw_time>=1.0/30.0:
		_redraw_time = fmod(_redraw_time,1.0/30.0)
		(_water.material as ShaderMaterial).set_shader_parameter("phase",phase)
		_layout_relief()
		queue_redraw()

func _draw() -> void:
	if size.x<=0 or size.y<=0: return
	var surface: float = size.y*0.235
	var station_width: float = size.x*0.255
	draw_texture_rect(STATION,Rect2(size.x*0.595,surface-station_width*0.32,station_width,station_width*0.375),false,Color(0.69,0.78,0.76))
	if not reduced_particles:
		for index: int in range(PARTICLE_COUNT):
			var x: float = fposmod(index*0.6180339+phase*0.0006,1.0)
			var y: float = fposmod(index*0.7548777+phase*0.0009,1.0)
			draw_circle(Vector2(size.x*(0.48+x*0.51),surface+18+y*(size.y-surface)),0.7+float(index%3)*0.35,Color(0.58,0.74,0.71,0.10+float(index%4)*0.018))
	var center: Vector2 = Vector2(size.x*0.69,size.y*0.53)
	var vessel_scale: float = clampf(size.x/560.0,1.55,3.3)
	draw_set_transform(center,0.16,Vector2.ONE*vessel_scale)
	var illumination: float = 1.0 if reduced_effects or reduced_motion else 0.97+sin(phase*0.4)*0.03
	draw_texture_rect(SEARCHLIGHT,Rect2(19,-28,240,56),false,Color(0.74,0.86,0.79,0.38*illumination))
	draw_texture_rect(VESSEL,Rect2(-40,-24,80,48),false)
	draw_set_transform(Vector2.ZERO)


func _layout_relief() -> void:
	if _cliffs.size()!=3: return
	var drift: float = sin(phase*0.07)*4.0
	var rectangles: Array[Rect2] = [Rect2(size.x*0.63+drift,size.y*0.34,size.x*0.42,size.y*0.85),
		Rect2(size.x*0.80-drift,size.y*0.42,size.x*0.38,size.y*0.91),
		Rect2(size.x*0.91+drift*1.5,size.y*0.66,size.x*0.25,size.y*0.65)]
	var tints: Array[Color] = [Color(0.52,0.69,0.73,0.34),Color(0.61,0.77,0.79,0.70),Color(0.35,0.47,0.48)]
	for index: int in range(3):
		_cliffs[index].position = rectangles[index].position
		_cliffs[index].size = rectangles[index].size
		_cliffs[index].modulate = tints[index]
