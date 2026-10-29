class_name SunlitOcean
extends Node2D
## Decorative horizon. The chapter owns a separate, fixed surface collision plane.
var phase: float = 0.0
var scene: ShelfPrototype
var _last_view: Rect2
var _tick: float = 0.0
var _column: Sprite2D
func configure(game: ShelfPrototype) -> void:
	scene = game
	z_index = -10
	_column = Sprite2D.new()
	_column.texture = preload("res://assets/art/sunlit/water_column.png")
	_column.centered = false
	_column.show_behind_parent = true
	_column.modulate = Color(0.45,0.62,0.65,0.55)
	var paint: ShaderMaterial = ShaderMaterial.new()
	paint.shader = preload("res://assets/shaders/submerged_water.gdshader")
	_column.material = paint
	add_child(_column)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera==null: return
	var view: Rect2 = Rect2(camera.get_screen_center_position()-get_viewport_rect().size*0.5,get_viewport_rect().size)

	var quiet: bool = scene.settings.snapshot().accessibility.reduced_motion
	var moving: bool = scene.submarine.is_physics_processing() and not quiet
	if moving: phase = fmod(phase+delta,TAU*100.0)
	_tick += delta
	if view!=_last_view or (moving and _tick>=0.05):
		_column.position = Vector2(view.position.x-200,0)
		_column.scale = Vector2((view.size.x+400)/_column.texture.get_width(),2000.0/_column.texture.get_height())
		_last_view = view
		_tick = 0.0
		queue_redraw()
func _draw() -> void:
	if _last_view.size==Vector2.ZERO: return
	var width: float = _last_view.size.x+400.0
	# Title art contains a baked horizon: never use it as the water column.
	draw_rect(Rect2(_last_view.position.x-200,-1200,width,1200),Color("030b10"))
	var reduced: bool = scene.settings.snapshot().accessibility.reduced_flashing
	for layer: int in range(2):
		var points: PackedVector2Array = []
		for index: int in range(65):
			var x: float = _last_view.position.x-200+width*index/64.0
			points.append(Vector2(x,sin(x*0.012+phase*0.5+layer)*1.8+sin(x*0.031-phase*0.3)*0.8+layer*3.0))
		draw_polyline(points,Color(0.42,0.67,0.70,0.22 if reduced else 0.45),1.2,true)
