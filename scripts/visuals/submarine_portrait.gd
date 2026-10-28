class_name SubmarinePortrait
extends Control
var vessel_name: String = "NERIS  /  01"
## Original illustrated cutaway; scalable vector shading, no external art assets.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var factor: float = minf(size.x/900.0,size.y/360.0)
	draw_set_transform((size-Vector2(900,360)*factor)*0.5,0,Vector2.ONE*factor)
	for index: int in range(12,0,-1): draw_circle(Vector2(450,190),index*24.0,Color(0.05,0.25,0.31,0.025))
	var shell: PackedVector2Array = PackedVector2Array([Vector2(140,180),Vector2(200,115),Vector2(640,115),Vector2(740,160),Vector2(790,192),Vector2(740,230),Vector2(640,255),Vector2(200,255),Vector2(140,215)])
	var shades: PackedColorArray = PackedColorArray([Color("29434b"),Color("acc8bf"),Color("c7d4c1"),Color("80a8a4"),Color("466d79"),Color("335460"),Color("152e3b"),Color("244450"),Color("466d79")])
	draw_polygon(shell,shades)
	shell.append(shell[0])
	draw_polyline(shell,Color("a6bdad"),3,true)
	draw_style_box(_panel(Color("536f72")),Rect2(345,65,190,65))
	draw_line(Vector2(425,65),Vector2(425,27),Color("97aaa0"),9)
	draw_line(Vector2(425,27),Vector2(480,27),Color("97aaa0"),8)
	draw_rect(Rect2(280,145,350,11),Color("e4c986"))
	for index: int in range(5):
		var at: Vector2 = Vector2(280+index*70,188)
		draw_circle(at,25,Color("142732"))
		draw_circle(at,20,Color("7fbecc"))
		draw_arc(at+Vector2(-2,-2),15,PI,TAU,20,Color("c7ecde"),3,true)
	for index: int in range(13): draw_circle(Vector2(215+index*35,237),2,Color("9da991"))
	draw_style_box(_panel(Color("213a45")),Rect2(110,155,52,76))
	draw_line(Vector2(108,130),Vector2(108,255),Color("759e9d"),8)
	draw_string(ThemeDB.fallback_font,Vector2(480,225),vessel_name,HORIZONTAL_ALIGNMENT_LEFT,-1,UiTypography.base(&"hud"),Color("d6d7b9"))
	draw_colored_polygon(PackedVector2Array([Vector2(750,160),Vector2(782,191),Vector2(750,218),Vector2(719,207),Vector2(719,170)]),Color("88cbd6"))
func _panel(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.border_color = Color("90b6b1")
	style.set_border_width_all(2)
	return style
