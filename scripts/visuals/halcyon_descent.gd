class_name HalcyonDescent
extends Control
## Presentation clock only. No player, physics, input, random-stream or save access.
const VESSEL: Texture2D = preload("res://assets/art/identity/lantern_2.svg")
const STATION: Texture2D = preload("res://assets/art/identity/halcyon_modules.svg")
const WATER: Texture2D = preload("res://assets/art/identity/descent_water.svg")
const CLIFF: Texture2D = preload("res://assets/art/identity/shelf_cliff.svg")
const PARTICLE_COUNT: int = 42
var phase: float = 0.0
var reduced_motion: bool = false
var reduced_effects: bool = false
var reduced_particles: bool = false
var _redraw_time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	visibility_changed.connect(_visibility_changed)

func apply_preferences(value: Dictionary) -> void:
	reduced_motion = bool(value.reduced_motion)
	reduced_effects = bool(value.reduced_flashing)
	reduced_particles = bool(value.reduced_particles)
	# Use a stable authored pose for the static comfort alternative.
	if reduced_motion: phase = 0.0
	set_process(not reduced_motion and is_visible_in_tree())
	queue_redraw()

func _visibility_changed() -> void:
	set_process(not reduced_motion and is_visible_in_tree())

func _process(delta: float) -> void:
	if not is_visible_in_tree() or reduced_motion: return
	phase = fmod(phase+delta,1200.0)
	_redraw_time += delta
	if _redraw_time>=1.0/30.0:
		_redraw_time = fmod(_redraw_time,1.0/30.0)
		queue_redraw()

func _draw() -> void:
	if size.x<=0 or size.y<=0: return
	draw_texture_rect(WATER,Rect2(Vector2.ZERO,size),false)
	var surface: float = size.y*0.28
	var drift: float = sin(phase*0.07)*4.0
	# Two low-contrast shelves, then one close cut face; left remains navigation space.
	draw_texture_rect(CLIFF,Rect2(size.x*0.63+drift,size.y*0.34,size.x*0.42,size.y*0.85),false,Color(0.52,0.69,0.73,0.34))
	draw_texture_rect(CLIFF,Rect2(size.x*0.80-drift,size.y*0.42,size.x*0.38,size.y*0.91),false,Color(0.61,0.77,0.79,0.70))
	var station_width: float = size.x*0.255
	draw_texture_rect(STATION,Rect2(size.x*0.595,surface-station_width*0.32,station_width,station_width*0.375),false,Color(0.69,0.78,0.76))
	# Narrow ocean surface and broken reflections, never a full-screen displacement pass.
	for index: int in range(25):
		var x: float = size.x*(0.44+index*0.024)
		var wave: float = 0.0 if reduced_motion else sin(phase*0.3+index*0.8)*1.4
		draw_line(Vector2(x,surface+wave),Vector2(x+size.x*0.018,surface+wave),Color(0.35,0.55,0.56,0.14),1.0,true)
	for index: int in range(7):
		var width: float = (15.0+index*6)*size.x/1280.0
		draw_line(Vector2(size.x*0.721-width*0.5,surface+8+index*5),Vector2(size.x*0.721+width*0.5,surface+8+index*5),Color(0.71,0.65,0.47,0.10-index*0.01),1.0,true)
	if not reduced_particles:
		for index: int in range(PARTICLE_COUNT):
			var x: float = fposmod(index*0.6180339+phase*0.0006,1.0)
			var y: float = fposmod(index*0.7548777+phase*0.0009,1.0)
			draw_circle(Vector2(size.x*(0.48+x*0.51),surface+18+y*(size.y-surface)),0.7+float(index%3)*0.35,Color(0.58,0.74,0.71,0.10+float(index%4)*0.018))
	var center: Vector2 = Vector2(size.x*0.69,size.y*0.53)
	var vessel_scale: float = clampf(size.x/560.0,1.55,3.3)
	draw_set_transform(center,0.16,Vector2.ONE*vessel_scale)
	var illumination: float = 1.0 if reduced_effects or reduced_motion else 0.97+sin(phase*0.4)*0.03
	for index: int in range(4):
		var reach: float = 95.0+index*22.0
		draw_colored_polygon(PackedVector2Array([Vector2(29,0),Vector2(reach,-reach*0.15),Vector2(reach,reach*0.15)]),Color(0.68,0.78,0.63,0.024*illumination))
	draw_texture_rect(VESSEL,Rect2(-40,-24,80,48),false)
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect(CLIFF,Rect2(size.x*0.91+drift*1.5,size.y*0.66,size.x*0.25,size.y*0.65),false,Color(0.35,0.47,0.48))
