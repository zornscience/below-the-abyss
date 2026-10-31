class_name TwilightShelfLayout
extends Node2D
## Handcrafted bidirectional graybox. Owns geometry only, never campaign progress.
const SPAWN: Vector2 = Vector2(33000,1400)
const CAMERA: Rect2i = Rect2i(27000,800,12000,3200)
const WEST_LOOP: Array[Vector2] = [SPAWN,Vector2(30600,1400),Vector2(29000,1800),Vector2(29000,2900),Vector2(33000,2900),Vector2(35800,2900),Vector2(35800,1400),SPAWN]
const EAST_LOOP: Array[Vector2] = [SPAWN,Vector2(35800,1400),Vector2(37800,1800),Vector2(37800,3200),Vector2(35000,3200),Vector2(35000,2900),Vector2(35800,2900),Vector2(35800,1400),SPAWN]
var bodies: Array[GrayboxRock] = []
func configure(paint: ShaderMaterial) -> void:
	var water: Polygon2D = Polygon2D.new()
	water.polygon = SunlitSurveyData._rect(Rect2(CAMERA))
	water.texture = preload("res://assets/art/twilight/deep_water.png")
	var size: Vector2 = water.texture.get_size()
	water.uv = PackedVector2Array([Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)])
	water.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	water.color = Color(0.5,0.62,0.7,1)
	water.z_index = -20
	add_child(water)
	for polygon: PackedVector2Array in contours():
		var body: GrayboxRock = preload("res://scenes/props/graybox_rock.tscn").instantiate() as GrayboxRock
		body.outline = polygon
		body.draw_outline = false
		add_child(body)
		(body.get_node("Silhouette") as Polygon2D).material = paint
		bodies.append(body)
	var tether: Sprite2D = Sprite2D.new()
	tether.texture = preload("res://assets/art/sunlit/service_cradle.png")
	tether.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tether.position = SPAWN+Vector2(0,120)
	tether.scale = Vector2.ONE*220.0/tether.texture.get_width()
	add_child(tether)
	set_enabled(false)
static func contours() -> Array[PackedVector2Array]:
	var shapes: Array[Rect2] = [Rect2(27000,700,12000,200),Rect2(27000,3900,12000,200),Rect2(26900,700,200,3400),Rect2(38900,700,200,3400),
		Rect2(30000,1700,5000,900),Rect2(36600,2100,700,700),Rect2(30500,3300,3500,600),
		Rect2(27500,2200,700,300),Rect2(27800,2500,400,500),Rect2(38000,1100,900,350),
		Rect2(28500,3400,800,500),Rect2(35100,3500,3200,400)]
	var result: Array[PackedVector2Array] = []
	for index: int in range(shapes.size()): result.append(SunlitSurveyData.rough_contour(SunlitSurveyData._rect(shapes[index]),index+180))
	return result
func set_enabled(value: bool) -> void:
	visible = value
	for body: GrayboxRock in bodies: body.collision_layer = 1 if value else 0
