class_name DrownedCavesLayout
extends Node2D
## Zone 3 graybox (DC-1 foundation, DC-2 navigation): an entry chamber, a passage, one flooded
## squeeze with a gated shortcut, and a far chamber that ends against a sealed wall. Owns geometry
## only, never campaign progress. Depth is the shared world mapping (0.25 m per unit), so the cave
## reads about 1,000 to 1,600 m. Later issues add the first-contact site; nothing here is a level.
const SPAWN: Vector2 = Vector2(43600,4800)
const CAMERA: Rect2i = Rect2i(42000,4000,13800,2400)
## Where the passage meets the squeeze system (the tunnel's local entrance, in world space).
const PASSAGE_END: Vector2 = Vector2(49700,5250)
## The far chamber's open water, past the squeeze. DC-4 places the first-contact site here.
const FAR_CHAMBER: Vector2 = Vector2(54000,5250)
const TUNNELS: TunnelSetProfile = preload("res://resources/world/drowned_caves_tunnels.tres")
# Rock masses, in order. Index 5 is the squeeze mass: the tunnel profile replaces it by index.
const SHAPES: Array[Rect2] = [
	Rect2(41800,3800,14400,200),Rect2(41800,6400,14400,200),Rect2(41800,3800,200,2800),Rect2(55600,3800,300,2800),
	Rect2(44800,4000,300,1100),
	Rect2(49800,4000,2000,2400),
	Rect2(47000,4000,2800,1000),Rect2(47000,5500,2800,900),
	Rect2(53400,4000,300,1100)]
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
static func base_contours() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for index: int in range(SHAPES.size()):
		result.append(SunlitSurveyData.rough_contour(SunlitSurveyData._rect(SHAPES[index]),index+300))
	return result
## Every solid outline, with the squeeze mass carved to its authored tunnel system.
static func contours() -> Array[PackedVector2Array]:
	return TwilightTunnelCatalog.contours(base_contours(),TUNNELS)
## The authored route length between two world points along a path of points.
static func path_length(path: PackedVector2Array) -> float:
	return TunnelProfile.length(path)
## Anchor to the far chamber by the always-open long route (down the squeeze), in world space.
static func long_route() -> PackedVector2Array:
	var profile: TunnelProfile = TUNNELS.systems[0] as TunnelProfile
	var route: PackedVector2Array = profile.approach.duplicate()
	route.append_array(profile.world_path(profile.main))
	route.append(FAR_CHAMBER)
	return route
## Anchor to the far chamber through the gated shortcut, in world space.
static func shortcut_route() -> PackedVector2Array:
	var profile: TunnelProfile = TUNNELS.systems[0] as TunnelProfile
	var route: PackedVector2Array = profile.approach.duplicate()
	route.append(profile.origin+profile.main[0])
	route.append_array(profile.world_path(profile.shortcut))
	route.append(profile.origin+profile.main[-1])
	route.append(FAR_CHAMBER)
	return route
func set_enabled(value: bool) -> void:
	visible = value
	for body: GrayboxRock in bodies: body.collision_layer = 1 if value else 0
