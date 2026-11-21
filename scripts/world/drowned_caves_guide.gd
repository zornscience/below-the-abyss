class_name DrownedCavesGuide
extends Node2D
## DC-3: the sentinel payoff in the Drowned Caves. A released, living sentinel leaves a trail of soft
## lights along the long route (the route that is always open). They are optional: nothing requires
## following them and nothing gates on them. A captured, lost or later-killed animal leaves no lights
## and one line of text. There is no hostility in any variant (brief decision D); the Warden flags set
## by Twilight (`zone2-wardens-wary`, `zone2-wardens-hostile`) change only the words. Availability is
## derived from existing story flags, so no save field exists. Owns presentation only.
const SPACING: float = 1200.0
## The authored lines, all flagged for designer review.
const TEXT: Dictionary = {
	&"guide":"Wick: A light ahead, low and steady, where the passage bends. It is not ours.\n\nOkafor: The animal you freed. It is keeping its distance and waiting. You do not have to follow it.",
	&"guide_lost":"Wick: No lights ahead.\n\nOkafor: The animal that would have gone first is dead. We find the way ourselves.",
	&"captured":"Wick: No lights. The water is quiet in a way I do not like.\n\nOkafor: Nothing here has moved against us. Take it slowly.",
	&"lost":"Wick: No lights, and nothing answering.\n\nOkafor: The animal died in the net. If anything here remembers that, it has not shown itself. Take it slowly."}
var _time: float = 0.0
var _static: bool = false
var _contrast: bool = false
var _lights: PackedVector2Array = waypoints()
var scene: ShelfPrototype
## Evenly spaced points along the always-open long route, ending in the far chamber.
static func waypoints() -> PackedVector2Array:
	var route: PackedVector2Array = DrownedCavesLayout.long_route()
	var result: PackedVector2Array = []
	var travelled: float = 0.0
	var next: float = SPACING
	for index: int in range(route.size()-1):
		var length: float = route[index].distance_to(route[index+1])
		if length<0.001: continue
		while travelled+length>=next:
			result.append(route[index].lerp(route[index+1],(next-travelled)/length))
			next += SPACING
		travelled += length
	if result.is_empty() or result[-1].distance_to(DrownedCavesLayout.FAR_CHAMBER)>SPACING*0.25:
		result.append(DrownedCavesLayout.FAR_CHAMBER)
	return result
## Which reaction the story state earns. Pure: reads flags and decisions only.
static func variant(story: StoryState) -> StringName:
	if story.has_decision(TwilightShelfData.RELEASE) or story.has_flag(&"zone2-future-guide"):
		return &"guide_lost" if story.has_flag(&"zone2-released-sentinel-lost") else &"guide"
	if story.has_decision(TwilightShelfData.CAPTURE): return &"captured"
	if story.has_decision(TwilightShelfData.LOST): return &"lost"
	return &""
static func available(story: StoryState) -> bool:
	return variant(story)==&"guide"
static func reaction(story: StoryState) -> String:
	return String(TEXT.get(variant(story),""))
func setup(game: ShelfPrototype) -> void:
	scene = game
	z_index = 2
	scene.settings.settings_changed.connect(_preferences)
	_preferences()
	set_enabled(false)
func lights() -> PackedVector2Array:
	return _lights
func set_enabled(value: bool) -> void:
	visible = value
	set_process(value)
## Reduced motion or reduced flashing make the lights steady; high contrast adds a bright ring.
func _preferences() -> void:
	var accessibility: Dictionary = scene.settings.snapshot().accessibility
	_static = bool(accessibility.get("reduced_motion",false)) or bool(accessibility.get("reduced_flashing",false))
	_contrast = bool(accessibility.get("high_contrast",false))
	modulate.a = 1.0
	queue_redraw()
func is_steady() -> bool:
	return _static
func _process(delta: float) -> void:
	if _static:
		modulate.a = 1.0
		return
	_time += delta
	# A slow swell, never a flash: about 0.3 Hz between 70% and 100%.
	modulate.a = 0.85+0.15*sin(_time*1.8)
func _draw() -> void:
	var glow: Color = Color(0.55,0.95,0.85)
	for at: Vector2 in _lights:
		draw_circle(at,90.0,Color(glow,0.10))
		draw_circle(at,46.0,Color(glow,0.22))
		draw_circle(at,14.0,Color(0.9,1.0,0.96,0.95))
		# A ring as well as a glow, so the marker never depends on colour alone.
		draw_arc(at,62.0,0.0,TAU,40,Color(1,1,1,0.95) if _contrast else Color(glow,0.7),6.0 if _contrast else 3.0)
