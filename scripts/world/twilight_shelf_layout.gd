class_name TwilightShelfLayout
extends Node2D
## Handcrafted bidirectional shelf. Owns geometry only, never campaign progress.
const SPAWN: Vector2 = Vector2(33000,1400)
const DEPTH_GATE: DepthGateProfile = preload("res://resources/balance/twilight_depth_gate.tres")
const CAMERA: Rect2i = Rect2i(27000,800,12000,4400)
const WEST_LOOP: Array[Vector2] = [SPAWN,Vector2(30600,1400),Vector2(29000,1800),Vector2(29000,2900),Vector2(33000,2900),Vector2(35800,2900),Vector2(35800,1400),SPAWN]
const EAST_LOOP: Array[Vector2] = [SPAWN,Vector2(35800,1400),Vector2(37800,1800),Vector2(37800,3200),Vector2(35000,3200),Vector2(35000,2900),Vector2(35800,2900),Vector2(35800,1400),SPAWN]
# Two vertical chimneys join a transverse wreck gallery. End pockets are reversible.
const INNER_LOOP: Array[Vector2] = [SPAWN,Vector2(31950,1400),Vector2(31950,2300),Vector2(33450,2300),Vector2(33450,2900),Vector2(35800,2900),Vector2(35800,1400),SPAWN]
const WEST_POCKET: Vector2 = Vector2(31100,2300)
const EAST_POCKET: Vector2 = Vector2(34100,2300)
var bodies: Array[GrayboxRock] = []
var tunnel_bodies: Array[GrayboxRock] = []
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
	var original: Array[PackedVector2Array] = base_contours()
	for polygon: PackedVector2Array in TwilightTunnelCatalog.contours(original):
		var body: GrayboxRock = preload("res://scenes/props/graybox_rock.tscn").instantiate() as GrayboxRock
		body.outline = polygon
		body.draw_outline = false
		add_child(body)
		(body.get_node("Silhouette") as Polygon2D).material = paint
		bodies.append(body)
		if polygon not in original: tunnel_bodies.append(body)
	var tether: Sprite2D = Sprite2D.new()
	tether.texture = preload("res://assets/art/sunlit/service_cradle.png")
	tether.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tether.position = SPAWN+Vector2(0,120)
	tether.scale = Vector2.ONE*220.0/tether.texture.get_width()
	add_child(tether)
	set_enabled(false)
static func contours() -> Array[PackedVector2Array]:
	return TwilightTunnelCatalog.contours(base_contours())
static func base_contours() -> Array[PackedVector2Array]:
	# Original exterior bodies retain their authored noise seeds; only the central
	# solid mass is carved. Joined concave outlines avoid seams between rock tiles.
	var shapes: Array[Rect2] = [Rect2(27000,700,12000,200),Rect2(27000,DEPTH_GATE.floor_y,12000,200),Rect2(26900,700,200,4600),Rect2(38900,700,200,4600),
		Rect2(36600,2100,700,700),Rect2(30500,3300,2000,600),
		Rect2(27500,2200,700,300),Rect2(27800,2500,400,500),Rect2(38000,1100,900,350),
		Rect2(28500,3400,800,500),Rect2(35100,3500,3200,400)]
	var result: Array[PackedVector2Array] = []
	for index: int in range(shapes.size()):
		result.append(SunlitSurveyData.rough_contour(SunlitSurveyData._rect(shapes[index]),index+180+(1 if index>=4 else 0)))
	var gallery: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(0,0),Vector2(1800,0),Vector2(1800,450),Vector2(1000,450),Vector2(900,550),Vector2(900,650),Vector2(1000,750),Vector2(1800,750),Vector2(1800,900),Vector2(0,900)]),
		SunlitSurveyData._rect(Rect2(2100,0,1200,450)),
		SunlitSurveyData._rect(Rect2(2100,750,1200,150)),
		PackedVector2Array([Vector2(3600,0),Vector2(5000,0),Vector2(5000,900),Vector2(3600,900),Vector2(3600,750),Vector2(4200,750),Vector2(4300,650),Vector2(4300,550),Vector2(4200,450),Vector2(3600,450)])]
	for index: int in range(gallery.size()):
		# Round in local space, away from the shallow world's protected outer seams.
		var outline: PackedVector2Array = SunlitSurveyData.rough_contour(gallery[index],200+index)
		for point: int in range(outline.size()): outline[point] += Vector2(30000,1700)
		result.append(outline)
	return result

func set_enabled(value: bool) -> void:
	visible = value
	for body: GrayboxRock in bodies: body.collision_layer = 1 if value else 0
