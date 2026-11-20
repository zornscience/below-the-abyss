class_name DrownedCavesLayout
extends Node2D
## Zone 3: authored collision and entirely procedural cave dressing (no external art).
var bodies: Array[GrayboxRock] = []
var guide: Sprite2D
var crystal: Polygon2D
var collapsed_arch: GrayboxRock
var silt: Polygon2D
var active: bool = false
const ROCKS: Array[Rect2] = [
	Rect2(41800,3750,14800,280), Rect2(41800,7700,14800,400),
	Rect2(41800,3750,320,4500), Rect2(56300,3750,320,4500),
	Rect2(43800,3980,1200,210), Rect2(45000,5200,1700,520),
	Rect2(47900,4070,1900,890), Rect2(48900,5800,850,750),
	Rect2(50900,5910,1050,520), Rect2(52200,4810,1900,520),
	Rect2(53300,7250,2100,440), Rect2(45900,7160,2100,490),
	Rect2(49200,7170,2400,400)
]
func setup(paint: ShaderMaterial) -> void:
	name = "DrownedCavesLayout"
	var water: Polygon2D = Polygon2D.new()
	water.polygon = SunlitSurveyData._rect(Rect2(DrownedCavesData.CAMERA))
	water.color = Color(0.012,0.025,0.045,1.0)
	water.z_index = -21
	add_child(water)
	for index: int in range(ROCKS.size()):
		var rock: GrayboxRock = preload("res://scenes/props/graybox_rock.tscn").instantiate() as GrayboxRock
		rock.outline = SunlitSurveyData.rough_contour(SunlitSurveyData._rect(ROCKS[index]),index+500)
		rock.draw_outline = false
		rock.name = "CaveLimestone%d" % index
		add_child(rock)
		(rock.get_node("Silhouette") as Polygon2D).material = paint
		bodies.append(rock)
	for index: int in range(20):
		# Sparse bone-white stalactites form a readable upper silhouette.
		var x: float = 42900.0+float(index)*690.0
		var tip: float = 100.0+float(index%4)*58.0
		var tooth: Polygon2D = Polygon2D.new()
		tooth.polygon = PackedVector2Array([Vector2(x,4030),Vector2(x+125,4030),Vector2(x+66,4030+tip)])
		tooth.color = Color(0.17,0.21,0.23,0.9)
		tooth.z_index = -3
		add_child(tooth)
	_landmark("ASCENT ROUTE / HALCYON",DrownedCavesData.EXIT+Vector2(-300,-225))
	_landmark("THE HUMAN ACCOUNT",Vector2(45800,4500))
	_landmark("THE OTHER ACCOUNT",Vector2(47500,5350))
	_landmark("ARCHIVE / DISTURB NOTHING",DrownedCavesData.SHRINE+Vector2(-580,-460))
	var silt_bank: Polygon2D = Polygon2D.new()
	silt_bank.polygon = SunlitSurveyData._rect(Rect2(47800,6280,2600,660))
	silt_bank.color = Color(0.27,0.31,0.33,0.2)
	silt_bank.z_index = 2
	add_child(silt_bank)
	silt = silt_bank
	var pedestal: Polygon2D = Polygon2D.new()
	pedestal.polygon = PackedVector2Array([Vector2(-135,145),Vector2(140,145),Vector2(175,200),Vector2(-170,200)])
	pedestal.position = DrownedCavesData.SHRINE
	pedestal.color = Color(0.19,0.35,0.38)
	add_child(pedestal)
	crystal = Polygon2D.new()
	crystal.polygon = PackedVector2Array([Vector2(-70,0),Vector2(0,-175),Vector2(72,0),Vector2(0,100)])
	crystal.position = DrownedCavesData.SHRINE
	crystal.color = Color(0.45,0.88,0.91,0.78)
	add_child(crystal)
	guide = Sprite2D.new()
	guide.texture = preload("res://assets/art/twilight/sentinel.png")
	guide.scale = Vector2.ONE*230.0/guide.texture.get_width()
	guide.position = Vector2(48000,6100)
	guide.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(guide)
	collapsed_arch = preload("res://scenes/props/graybox_rock.tscn").instantiate() as GrayboxRock
	collapsed_arch.outline = SunlitSurveyData._rect(Rect2(54620,6220,440,500))
	collapsed_arch.draw_outline = false
	add_child(collapsed_arch)
	(collapsed_arch.get_node("Silhouette") as Polygon2D).material = paint
	set_enabled(false)
func _landmark(text: String,at: Vector2) -> void:
	var caption: Label = Label.new()
	caption.text = text
	caption.position = at
	caption.add_theme_font_size_override("font_size",29)
	caption.add_theme_color_override("font_color",Color(0.68,0.77,0.79))
	caption.z_index = 5
	add_child(caption)
func set_enabled(value: bool) -> void:
	active = value
	visible = value
	for rock: GrayboxRock in bodies: rock.collision_layer = 1 if value else 0
	collapsed_arch.collision_layer = 1 if value and collapsed_arch.visible else 0
func refresh_story(story: StoryState) -> void:
	var taken: bool = story.has_decision(DrownedCavesData.TAKE)
	crystal.visible = not taken
	collapsed_arch.visible = taken
	collapsed_arch.collision_layer = 1 if active and taken else 0
	guide.visible = story.has_decision(TwilightShelfData.RELEASE) and not story.has_flag(&"zone2-released-sentinel-lost")
func silt_current(at: Vector2) -> Vector2:
	if not active or not Rect2(47800,6280,2600,660).has_point(at): return Vector2.ZERO
	return Vector2(-9.0,-4.0) if guide.visible else Vector2(-18.0,-8.0)
