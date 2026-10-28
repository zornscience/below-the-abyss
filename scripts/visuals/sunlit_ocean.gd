class_name SunlitOcean
extends Node2D
## Decorative horizon. The chapter owns a separate, fixed surface collision plane.
var phase: float = 0.0
var scene: ShelfPrototype
var _last_view: Rect2
var _tick: float = 0.0
func configure(game: ShelfPrototype) -> void:
	scene = game
	z_index = -10
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera==null: return
	var view: Rect2 = Rect2(camera.get_screen_center_position()-get_viewport_rect().size*0.5,get_viewport_rect().size)
	if view.position.y>600: return
	var quiet: bool = scene.settings.snapshot().accessibility.reduced_motion
	var moving: bool = scene.submarine.is_physics_processing() and not quiet
	if moving: phase = fmod(phase+delta,TAU*100.0)
	_tick += delta
	if view!=_last_view or (moving and _tick>=0.05):
		_last_view = view
		_tick = 0.0
		queue_redraw()
func _draw() -> void:
	if _last_view.size==Vector2.ZERO: return
	var width: float = _last_view.size.x+400.0
	var height: float = width*HalcyonDescent.WATER.get_height()/HalcyonDescent.WATER.get_width()
	draw_rect(Rect2(_last_view.position.x-200,-1000,width,1000),Color("030b10"))
	draw_texture_rect(HalcyonDescent.WATER,Rect2(_last_view.position.x-200,-height*0.235,width,height),false,Color(0.55,0.72,0.76,0.85))
	var reduced: bool = scene.settings.snapshot().accessibility.reduced_flashing
	for layer: int in range(2):
		var points: PackedVector2Array = []
		for index: int in range(65):
			var x: float = _last_view.position.x-200+width*index/64.0
			points.append(Vector2(x,sin(x*0.012+phase*0.5+layer)*1.8+sin(x*0.031-phase*0.3)*0.8+layer*3.0))
		draw_polyline(points,Color(0.42,0.67,0.70,0.22 if reduced else 0.45),1.2,true)
