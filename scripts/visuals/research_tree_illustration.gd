class_name ResearchTreeIllustration
extends Control
var branch: String = "sonar"
var rank: int = 0
var text_scale: float = 1.0
var values: PackedFloat32Array
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = 220*text_scale
	resized.connect(queue_redraw)
func _draw() -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color("0c2530")
	box.set_corner_radius_all(14)
	draw_style_box(box,Rect2(Vector2(0,0),size-Vector2(6,0)))
	for index: int in range(1,4):
		var at: Vector2 = Vector2(42,36*text_scale+(index-1)*73*text_scale)
		var assigned: bool = index<=rank
		var accent: Color = Color("e0ce94") if assigned else Color("6b9baf")
		if index>1: draw_line(at-Vector2(0,49),at-Vector2(0,24),accent.darkened(0.4),3,true)
		draw_circle(at,26,Color("294852") if assigned else Color("10202e"))
		draw_arc(at,25,0,TAU,40,accent,2,true)
		if branch=="sonar":
			for radius: int in [7,13,19]: draw_arc(at+Vector2(-6,0),radius,-PI*0.4,PI*0.4,18,accent,2,true)
		else:
			var shield: PackedVector2Array = PackedVector2Array([at+Vector2(-12,-12),at+Vector2(12,-12),at+Vector2(10,6),at+Vector2(0,15),at+Vector2(-10,6),at+Vector2(-12,-12)])
			draw_polyline(shield,accent,2,true)
		draw_string(ThemeDB.fallback_font,at+Vector2(38,-2),"%s · %.0f %s" % [["I","II","III"][index-1],values[index],"range" if branch=="sonar" else "m"],HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(20*text_scale),accent)
		draw_string(ThemeDB.fallback_font,at+Vector2(38,19),"ASSIGNED" if assigned else ("NEXT RANK" if index==rank+1 else "REQUIRES PRIOR RANK"),HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(16*text_scale),Color("aac3c2"))
