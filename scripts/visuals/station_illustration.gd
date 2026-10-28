class_name StationIllustration
extends Control
var station_name: String = "SHELF BASE"
## Vector cutaway illustration shared by the docking page and station landmark.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var s: float = minf(size.x/900.0,size.y/360.0)
	var origin: Vector2 = (size-Vector2(900,360)*s)*0.5
	draw_set_transform(origin,0,Vector2.ONE*s)
	draw_rect(Rect2(0,0,900,360),Color("081e29"))
	for x: int in range(30,900,75):
		draw_line(Vector2(x,0),Vector2(x,360),Color("17333b"),1)
	for y: int in range(30,360,60):
		draw_line(Vector2(0,y),Vector2(900,y),Color("17333b"),1)
	draw_line(Vector2(40,312),Vector2(860,312),Color("506e70"),7)
	for x: float in [170.0,510.0,750.0]:
		draw_line(Vector2(x,245),Vector2(x-30,312),Color("69878a"),12)
	_draw_module(Rect2(110,125,230,125),"HABITAT",Color("c6c8b4"))
	_draw_module(Rect2(360,95,220,155),"RESEARCH",Color("8caaa7"))
	_draw_module(Rect2(605,145,185,105),"DOCK 01",Color("b5a779"))
	draw_line(Vector2(340,200),Vector2(360,200),Color("7c9695"),28)
	draw_line(Vector2(580,200),Vector2(605,200),Color("7c9695"),28)
	draw_arc(Vector2(790,197),58,-PI*0.5,PI*0.5,32,Color("b5a779"),8,true)
	draw_line(Vector2(470,95),Vector2(470,30),Color("829c98"),6)
	draw_arc(Vector2(470,30),25,PI,TAU,24,Color("829c98"),3,true)
	draw_circle(Vector2(470,30),4,Color("d9e0a6"))
	draw_string(ThemeDB.fallback_font,Vector2(135,115),station_name,HORIZONTAL_ALIGNMENT_LEFT,-1,UiTypography.base(&"hud"),Color("dce4ca"))
	for x: int in range(150,800,45):
		draw_line(Vector2(x,275),Vector2(x+16,275),Color("d9c687"),3)
func _draw_module(rect: Rect2,label: String,ink: Color) -> void:
	draw_style_box(_style(ink),rect)
	for index: int in range(3):
		var window: Rect2 = Rect2(rect.position+Vector2(22+index*53,30),Vector2(32,32))
		draw_rect(window,Color("203b43"))
		draw_rect(window.grow(-5),Color("bea76f"))
	draw_string(ThemeDB.fallback_font,rect.position+Vector2(18,rect.size.y-18),label,HORIZONTAL_ALIGNMENT_LEFT,-1,UiTypography.base(&"secondary"),Color("142c34"))
func _style(ink: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = ink
	style.set_corner_radius_all(20)
	style.border_color = Color("587779")
	style.set_border_width_all(3)
	return style
