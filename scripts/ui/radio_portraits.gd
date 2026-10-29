class_name RadioPortraits
extends RefCounted
## Provisional role portraits; identity remains explicit text, never image alone.
const SHEET: Texture2D = preload("res://assets/art/portraits/radio_crew.png")
static func identity(source: String) -> StringName:
	var key: String = source.to_lower()
	if "mara" in key: return &"mara"
	if "crane" in key: return &"crane"
	if "okafor" in key or "halcyon" in key or "shelf base" in key: return &"okafor"
	return &"wick"
static func portrait(source: String) -> AtlasTexture:
	var index: int = [&"okafor",&"crane",&"mara",&"wick"].find(identity(source))
	var image: AtlasTexture = AtlasTexture.new()
	image.atlas = SHEET
	image.region = Rect2(index*SHEET.get_width()/4.0,0,SHEET.get_width()/4.0,SHEET.get_height())
	image.filter_clip = true
	return image
