class_name DrownedCavesLayout
extends Node2D
## Zone 3 foundation (DC-1): graybox entry chamber, one passage and a sealed end. Owns geometry
## only, never campaign progress. Depth is the shared world mapping (0.25 m per unit), so the
## chamber reads about 1,000 to 1,500 m. Later issues extend the cave; nothing here is a level.
const SPAWN: Vector2 = Vector2(43600,4800)
const CAMERA: Rect2i = Rect2i(42000,4000,8000,2400)
## The one passage leaves the chamber eastward and ends against a sealed wall (DC-2 extends it).
const PASSAGE_END: Vector2 = Vector2(49500,5200)
var bodies: Array[GrayboxRock] = []
func configure(paint: ShaderMaterial) -> void:
	var water: Polygon2D = Polygon2D.new()
	water.polygon = SunlitSurveyData._rect(Rect2(CAMERA))
	water.texture = preload("res://assets/art/twilight/deep_water.png")
	var size: Vector2 = water.texture.get_size()
	water.uv = PackedVector2Array([Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)])
	water.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	water.color = Color(0.42,0.54,0.62,1)
	water.z_index = -20
	add_child(water)
	for polygon: PackedVector2Array in contours():
		var body: GrayboxRock = preload("res://scenes/props/graybox_rock.tscn").instantiate() as GrayboxRock
		body.outline = polygon
		body.draw_outline = false
		add_child(body)
		(body.get_node("Silhouette") as Polygon2D).material = paint
		bodies.append(body)
	var anchor: Sprite2D = Sprite2D.new()
	anchor.texture = preload("res://assets/art/sunlit/service_cradle.png")
	anchor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	anchor.position = SPAWN+Vector2(0,120)
	anchor.scale = Vector2.ONE*220.0/anchor.texture.get_width()
	add_child(anchor)
	set_enabled(false)
static func contours() -> Array[PackedVector2Array]:
	# Outer shell: ceiling, floor, west wall and the sealed east wall. The chamber is open
	# water from x 42200 to 47000. A stalactite column (the navigational landmark) hangs
	# from the ceiling. The east passage is cut between an upper and a lower block.
	var shapes: Array[Rect2] = [
		Rect2(41800,3800,8400,200),Rect2(41800,6400,8400,200),Rect2(41800,3800,200,2800),Rect2(49900,3800,300,2800),
		Rect2(44800,4000,300,1100),
		Rect2(47000,4000,2900,1000),Rect2(47000,5500,2900,900)]
	var result: Array[PackedVector2Array] = []
	for index: int in range(shapes.size()):
		result.append(SunlitSurveyData.rough_contour(SunlitSurveyData._rect(shapes[index]),index+300))
	return result
func set_enabled(value: bool) -> void:
	visible = value
	for body: GrayboxRock in bodies: body.collision_layer = 1 if value else 0
