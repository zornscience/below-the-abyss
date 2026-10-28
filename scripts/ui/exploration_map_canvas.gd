class_name ExplorationMapCanvas
extends Control
## Draw only an explicit discovered snapshot, public survey extent and own position.

var bounds: Rect2
var points: Array[PointOfInterest] = []
var player_position: Vector2
var report_caption: String = "LAST CONTACT · BASE REPORT"
var has_report: bool = false
var reported_position: Vector2
var selected_id: StringName
var survey_enabled: bool = false
var player_direction: Vector2 = Vector2.RIGHT
var survey_polygons: Array[PackedVector2Array] = []
var charted: Array[Rect2] = []
var zoom: float = 1.0
var center: Vector2

func _view() -> Rect2:
	if not survey_enabled or zoom<=1: return bounds
	var extent: Vector2 = bounds.size/zoom
	var focus: Vector2 = center.clamp(bounds.position+extent*0.5,bounds.end-extent*0.5)
	return Rect2(focus-extent*0.5,extent)


func _point(world: Vector2) -> Vector2:
	var view: Rect2 = _view()
	var available: Vector2 = size - Vector2(48, 64)
	var scale_value: float = minf(available.x / view.size.x, available.y / view.size.y)
	var origin: Vector2 = (size - view.size * scale_value) * 0.5
	return origin + (world - view.position) * scale_value


func _draw() -> void:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var ink: Color = Color("8ed9d3")
	var start: Vector2 = _point(bounds.position)
	var end: Vector2 = _point(bounds.end)
	draw_rect(Rect2(start, end - start), Color("0b202c"), true)
	for index: int in range(1, 5):
		var x: float = lerpf(start.x, end.x, index / 5.0)
		draw_line(Vector2(x, start.y), Vector2(x, end.y), Color("23404b"))
	for index: int in range(1, 4):
		var y: float = lerpf(start.y, end.y, index / 4.0)
		draw_line(Vector2(start.x, y), Vector2(end.x, y), Color("23404b"))
	draw_rect(Rect2(start, end - start), ink, false, 2.0)
	var font: Font = ThemeDB.fallback_font
	if survey_enabled:
		_draw_survey()
	draw_string(font, Vector2(24,24) if survey_enabled else start-Vector2(0,8), "SURVEY EXTENT / SURFACE Y = 0", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTypography.for_control(self,&"hud"), ink)
	for index: int in range(points.size()):
		var point: PointOfInterest = points[index]
		var at: Vector2 = _point(point.map_position)
		draw_rect(Rect2(at - Vector2(6, 6), Vector2(12, 12)), ink, false, 2.0)
		if selected_id == point.stable_id:
			draw_arc(at, 12, 0, TAU, 32, Color("f4dc94"), 2.0, true)
		draw_string(font, at + Vector2(10, -8), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTypography.for_control(self,&"hud"), ink)
	if has_report and (not survey_enabled or _view().has_point(reported_position)):
		var report: Vector2 = _point(reported_position)
		if survey_enabled:
			var radius: float = maxf(13,_point(reported_position+Vector2(1300,0)).x-report.x)
			for segment: int in range(12):
				draw_arc(report,radius,segment*TAU/12.0,(segment+0.65)*TAU/12.0,8,Color("dfba7d"),2,true)
		draw_arc(report,13,0,TAU,32,Color("dfba7d"),2,true)
		var caption_size: int = UiTypography.for_control(self,&"hud")
		var caption_width: float = font.get_string_size(report_caption,HORIZONTAL_ALIGNMENT_LEFT,-1,caption_size).x
		var caption_at: Vector2 = report+Vector2(18,26)
		caption_at.x = clampf(caption_at.x,8,maxf(8,size.x-caption_width-8))
		caption_at.y = clampf(caption_at.y,caption_size+8,size.y-8)
		draw_string(font,caption_at,report_caption,HORIZONTAL_ALIGNMENT_LEFT,-1,caption_size,Color("dfba7d"))
	var player: Vector2 = _point(player_position)
	var direction: Vector2 = player_direction.normalized() if survey_enabled else Vector2.UP
	var side: Vector2 = direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([player+direction*10,player-direction*6+side*6,player-direction*6-side*6]),Color("f4dc94"))
	draw_string(font, player + Vector2(12, 18), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTypography.for_control(self,&"hud"), Color("f4dc94"))

func _draw_survey() -> void:
	# Only charted geometry is supplied by the chapter adapter. No hidden POI metadata.
	for section: Rect2 in charted:
		var area: Rect2 = Rect2(_point(section.position),_point(section.end)-_point(section.position))
		draw_rect(area,Color("133e49"))
	for polygon: PackedVector2Array in survey_polygons:
		var shape: PackedVector2Array = []
		for at: Vector2 in polygon: shape.append(_point(at))
		if shape.size()>=3: draw_colored_polygon(shape,Color("63817d"))
	var station: Vector2 = _point(Vector2(420,480))
	draw_rect(Rect2(station-Vector2(5,5),Vector2(10,10)),Color("f4dc94"))
	draw_string(ThemeDB.fallback_font,station+Vector2(5,-24),"HALCYON",HORIZONTAL_ALIGNMENT_LEFT,-1,UiTypography.for_control(self,&"secondary"),Color("f4dc94"))
	# Hatching identifies unsurveyed space even with high contrast / no colour cues.
	for x: int in range(5000,22000,1000):
		var at: Vector2 = Vector2(x,500)
		var known: bool = false
		for section: Rect2 in charted:
			if section.has_point(at): known = true
		if not known:
			var pixel: Vector2 = _point(at)
			draw_line(pixel-Vector2(5,5),pixel+Vector2(5,5),Color("68858b"),2)
	if charted.size()==1:
		draw_string(ThemeDB.fallback_font,Vector2(24,size.y-14),"HATCHED = UNSURVEYED",HORIZONTAL_ALIGNMENT_LEFT,-1,UiTypography.for_control(self,&"secondary"),Color("b4c8c7"))
