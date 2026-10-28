class_name MarineAnimalPaint
extends Node2D
## Original shared illustration atlas; motion follows the existing collision-safe body.
const ATLAS: Texture2D = preload("res://assets/art/sunlit/marine_animals.png")
var species: int = 0
var body: AcousticCreature
var game: ShelfPrototype
var phase: float = 0.0
var sprite: Sprite2D
var _reduced: bool = false
var _facing: float = 1.0

func setup(owner_body: AcousticCreature,scene: ShelfPrototype,index: int) -> void:
	body = owner_body
	game = scene
	species = index
	body.illustrated = true
	sprite = Sprite2D.new()
	var texture: AtlasTexture = AtlasTexture.new()
	texture.atlas = ATLAS
	texture.region = Rect2(ATLAS.get_width()/3.0*species,0,ATLAS.get_width()/3.0,ATLAS.get_height())
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var width: float = [120.0,88.0,140.0][species]
	sprite.scale = Vector2.ONE*width/texture.get_width()
	add_child(sprite)
	game.settings.settings_changed.connect(_preferences)
	_preferences()

func _process(delta: float) -> void:
	if not is_instance_valid(body) or body._suspended or body._destroyed: return
	var reduced: bool = _reduced
	if absf(body.velocity.x)>1: _facing = signf(body.velocity.x)
	sprite.flip_h = _facing<0
	phase = 0.0 if reduced else fmod(phase+delta,TAU*10)
	sprite.rotation = 0.0 if reduced else sin(phase*(2.0 if species==0 else 0.9))*0.045
	sprite.skew = 0.0 if reduced or species!=0 else sin(phase*2.0)*0.08

func _preferences() -> void:
	_reduced = game.settings.snapshot().accessibility.reduced_motion
	if _reduced and sprite!=null:
		sprite.rotation = 0
		sprite.skew = 0
