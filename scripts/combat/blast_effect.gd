class_name BlastEffect
extends Node2D
## Illustrated pressure ring/debris. Comfort mode omits the bright core and debris.
var radius: float = 150.0
var elapsed: float = 0.0
var refractive: bool = false
var _lens: ColorRect
var reduced_effects: bool = false
func _ready() -> void:
	if not refractive or reduced_effects: return
	_lens = ColorRect.new()
	_lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lens.position = -Vector2.ONE*radius*2.0
	_lens.size = Vector2.ONE*radius*4.0
	var lens_material: ShaderMaterial = ShaderMaterial.new()
	lens_material.shader = preload("res://assets/shaders/impact_refraction.gdshader")
	_lens.material = lens_material
	add_child(_lens)
func advance(delta: float) -> void:
	elapsed += delta
	if _lens != null: (_lens.material as ShaderMaterial).set_shader_parameter("phase",clampf(elapsed/0.65,0.0,1.0))
	if elapsed >= 0.65:
		queue_free()
	queue_redraw()
func _draw() -> void:
	var t: float = clampf(elapsed / 0.65, 0.0, 1.0)
	var alpha: float = 1.0 - t
	draw_arc(Vector2.ZERO, maxf(1.0, radius * sqrt(t)), 0, TAU, 64, Color(0.96, 0.78, 0.4, alpha * 0.8), 3.0, true)
	if not reduced_effects:
		for index: int in range(8,0,-1):
			draw_circle(Vector2.ZERO,float(index)*9.0*alpha,Color(1.0,0.72+index*0.025,0.4+index*0.05,alpha*0.08))
		draw_circle(Vector2.ZERO,22.0*alpha,Color(1.0,0.98,0.85,alpha))
		for index: int in range(12):
			var direction: Vector2 = Vector2.from_angle(index * TAU / 12.0)
			draw_line(direction * radius * t * 0.4, direction * radius * t * 0.65, Color(0.8, 0.68, 0.45, alpha), 2.0)
