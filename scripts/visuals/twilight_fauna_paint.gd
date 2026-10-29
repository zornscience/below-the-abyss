class_name TwilightFaunaPaint
extends Node2D
## New wildlife art over the existing acoustic/collision-safe creature body.
const ATLAS: Texture2D = preload("res://assets/art/twilight/fauna_atlas.png")
var animal: AcousticCreature
var game: ShelfPrototype
var sprite: Sprite2D
var phase: float = 0.0
var _species: int
var _swim: ShaderMaterial
func setup(body: AcousticCreature,scene: ShelfPrototype,species: int) -> void:
	animal = body
	game = scene
	_species = species
	body.illustrated = true
	sprite = Sprite2D.new()
	var region: AtlasTexture = AtlasTexture.new()
	region.atlas = ATLAS
	region.region = Rect2(species*ATLAS.get_width()/3.0,0,ATLAS.get_width()/3.0,ATLAS.get_height())
	sprite.texture = region
	sprite.scale = Vector2.ONE*[150.0,125.0,90.0][species]/region.get_width()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_swim = ShaderMaterial.new()
	_swim.shader = preload("res://assets/shaders/fauna_swim.gdshader")
	_swim.set_shader_parameter("cell",Vector4(species/3.0,0,1.0/3.0,1))
	_swim.set_shader_parameter("mode",1 if species==0 else 3+species)
	sprite.material = _swim
	add_child(sprite)
	game.settings.settings_changed.connect(_preferences)
	_preferences()
func _preferences() -> void:
	var reduced: bool = game.settings.snapshot().accessibility.reduced_motion
	_swim.set_shader_parameter("amount",0.0 if reduced else 1.0)
	if reduced: sprite.rotation = 0.0
func _process(delta: float) -> void:
	if animal._suspended or animal._destroyed: return
	var reduced: bool = game.settings.snapshot().accessibility.reduced_motion
	if not reduced: phase = fmod(phase+delta*(1.4+animal.velocity.length()/70),TAU*20)
	if absf(animal.velocity.x)>1: sprite.flip_h = animal.velocity.x<0
	_swim.set_shader_parameter("phase",phase)
	if not reduced and animal.velocity.length()>1:
		var angle: float = atan2(animal.velocity.y,absf(animal.velocity.x))*signf(animal.velocity.x)
		sprite.rotation = lerp_angle(sprite.rotation,clampf(angle,-0.45,0.45),1.0-exp(-delta*4))
