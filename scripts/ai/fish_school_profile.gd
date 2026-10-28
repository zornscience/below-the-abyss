class_name FishSchoolProfile
extends Resource
@export_range(5,12) var population: int = 8
@export var speed: float = 45.0
@export var separation: float = 20.0
@export var turn_rate: float = 3.0
@export var reaction_seconds: float = 3.5
@export var hearing_range: float = 1100.0
@export var habitat: Rect2 = Rect2(-150,-80,300,160)
@export var sprite_sheet: Texture2D = preload("res://assets/art/sunlit/school_species.png")
@export_range(0,2) var species: int = 0

func is_valid() -> bool:
	return population>=5 and population<=12 and is_finite(speed) and speed>0 and speed<=200 \
		and is_finite(separation) and separation>=8 and separation<=32 and is_finite(turn_rate) and turn_rate>0 \
		and is_finite(reaction_seconds) and reaction_seconds>0 and reaction_seconds<=10 \
		and is_finite(hearing_range) and hearing_range>=0 and hearing_range<=1800 \
		and habitat.position.is_finite() and habitat.size.is_finite() and habitat.size.x>=280 and habitat.size.y>=150 \
		and sprite_sheet!=null and species>=0 and species<3

func texture() -> AtlasTexture:
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = sprite_sheet
	atlas.region = Rect2(sprite_sheet.get_width()/3.0*species,0,sprite_sheet.get_width()/3.0,sprite_sheet.get_height())
	return atlas
