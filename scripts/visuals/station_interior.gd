class_name StationInterior
extends Control
## Original shaded observation/debrief room, composed behind station navigation.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var s: float = minf(size.x/1100.0,size.y/500.0)
	draw_set_transform((size-Vector2(1100,500)*s)*0.5,0,Vector2.ONE*s)
	draw_rect(Rect2(0,0,1100,500),Color("10212c"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,0),Vector2(1100,0),Vector2(950,80),Vector2(150,80)]),Color("385058"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,500),Vector2(150,370),Vector2(950,370),Vector2(1100,500)]),Color("243940"))
	for index: int in range(9): draw_line(Vector2(index*140,500),Vector2(150+index*100,370),Color("43606a"),2)
	draw_style_box(_panel(Color("091a28"),Color("71949a")),Rect2(300,90,500,260))
	for index: int in range(4):
		draw_colored_polygon(PackedVector2Array([Vector2(315,330-index*18),Vector2(420+index*40,230-index*20),Vector2(590+index*25,290-index*13),Vector2(785,210+index*15),Vector2(785,337),Vector2(315,337)]),Color(0.03,0.15+index*0.025,0.21+index*0.018,0.8))
	for x: int in [310,550,790]: draw_line(Vector2(x,100),Vector2(x,340),Color("54777e"),8)
	draw_style_box(_panel(Color("2c4650"),Color("86a39c")),Rect2(40,110,190,250))
	for index: int in range(5):
		draw_rect(Rect2(65,135+index*42,135,25),Color("102b35"))
		draw_circle(Vector2(185,147+index*42),4,Color("a9d4ad"))
	draw_style_box(_panel(Color("283f4b"),Color("738c91")),Rect2(870,120,180,250))
	draw_rect(Rect2(900,155,120,100),Color("0b2637"))
	for index: int in range(4): draw_line(Vector2(915,180+index*17),Vector2(970+index*8,180+index*17),Color("90d2cd"),2)
	draw_colored_polygon(PackedVector2Array([Vector2(340,370),Vector2(760,370),Vector2(815,410),Vector2(280,410)]),Color("718a83"))
	draw_rect(Rect2(320,410,30,55),Color("172e39"))
	draw_rect(Rect2(745,410,30,55),Color("172e39"))
	for x: int in [200,550,900]:
		draw_rect(Rect2(x-65,32,130,10),Color("f0d9a1"))
		for index: int in range(5,0,-1): draw_rect(Rect2(x-75,25-index*3,150,20+index*7),Color(1,0.85,0.55,0.015))
	draw_string(ThemeDB.fallback_font,Vector2(450,65),"SHELF BASE  /  OPERATIONS",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("d3d5b7"))
func _panel(color: Color, rim: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = rim
	box.set_border_width_all(4)
	box.set_corner_radius_all(20)
	return box
