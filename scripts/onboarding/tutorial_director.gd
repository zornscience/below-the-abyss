class_name TutorialDirector
extends Node
## One optional, non-modal mechanic hint at a time; never routes or raw input logs.
signal message_changed(title: String, body: String)
var _scene: ShelfPrototype
var _visible_until: float = 0.0
var _clock: float = 0.0
var _shown: Dictionary[String, bool] = {}
var _current: String = ""
var _initial_position: Vector2
const TEXT: Dictionary = {
	"movement":["Take the helm","Use {move} to thrust. Release to coast; reverse to brake. Pause for controls, help or station orders."],
	"sonar":["See with sound","{sonar}: send a sonar pulse. Each ping costs 4 battery, much more than ordinary travel. Reveals arrive with the wave."],
	"scan":["Recover scientific evidence","Approach a revealed subject and press {interact} to scan. Stay in range; press again to cancel. A progress bar appears above the instruments."],
	"map":["Keep your own bearings","{map}: open discovered landmarks and research. The map records what you found; it does not draw a route for you."],
	"station":["Dock and prepare","Inside the station ring, slow down and press {interact}. Repair, refill and upgrades are intentional; arriving alone restores nothing."],
	"depth":["Respect the pressure rating","Depth is shown beside your hull rating. CAUTION means you are near it; DANGER means ascend. Install the pressure hull before a deep investigation."],
	"wildlife":["A living acoustic landmark","Grazers investigate nearby sound, then return to feeding. Passive listening is silent. You can study wildlife without harming it."],
	"torpedo":["A tool with consequences","{fire}: fire in your last thrust direction (2 battery; 1.2s rearm). Explosions excavate soft rock and damage nearby wildlife. Hard perimeter bedrock and the station remain solid."]}
func setup(scene: ShelfPrototype) -> void:
	_scene = scene
	_initial_position = scene.submarine.global_position
	scene.settings.settings_changed.connect(_preferences_changed)
	scene.submarine.sonar.pulse_emitted.connect(func(_event: AcousticEvent) -> void: complete("sonar"); show_hint("scan"))
	scene.research.scan_completed.connect(func(_id: StringName) -> void: complete("scan"); show_hint("map"))
	scene.exploration_map.visibility_changed.connect(func() -> void:
		if scene.exploration_map.visible: complete("map"))
	scene.station_menu.visibility_changed.connect(func() -> void:
		if scene.station_menu.visible: complete("station"))
	scene.submarine.damage_system.warning_changed.connect(func(state: int) -> void:
		if state != SubmarineDamageSystem.WarningState.SAFE: show_hint("depth"))
	scene.torpedoes.fired.connect(func(_id: StringName) -> void: complete("torpedo"))
func _preferences_changed() -> void:
	if not _scene.settings.snapshot().onboarding.enabled:
		_current = ""
		message_changed.emit("","")
func _body(id: String) -> String:
	var text: String = TEXT[id][1]
	if _scene.revision!=null and id=="station": text = "Inside the station ring, slow down and press {interact}. Docking automatically repairs, refills and rearms. Spend or freely reassign your finite research points in Research technology."
	if _scene.revision!=null and id=="torpedo": text = "{fire}: launch one of ten torpedoes in the direction NERIS faces. The torpedo accelerates and leaves a fading wake. Explosions excavate soft rock and damage wildlife. Dock to rearm."
	if _scene.revision!=null and id=="movement": text = "Use {move} to thrust. NERIS takes time to accelerate in water; release to coast and reverse to brake. Base will radio an investigation after you depart."
	if _scene.chapter!=null and _scene.chapter.active:
		if id=="depth": text = "Watch hull, battery and oxygen. Pings cost more power than cruising. Return to Halcyon and deliberately dock to repair and refill; passing the station restores nothing."
		text = text.replace("NERIS","Lantern-2").replace("Base will radio an investigation after you depart.","Study the light bloom, then search near Twin Spires for Lantern-1’s buoy.")
	return text.replace("{move}"," / ".join([_scene.input_context.describe(&"move_up"),_scene.input_context.describe(&"move_left"),_scene.input_context.describe(&"move_down"),_scene.input_context.describe(&"move_right")])).replace("{sonar}",_scene.input_context.describe(&"sonar_ping")).replace("{interact}",_scene.input_context.describe(&"interact")).replace("{map}",_scene.input_context.describe(&"open_map")).replace("{fire}",_scene.input_context.describe(&"fire_torpedo"))
func show_hint(id: String, repeat: bool = false) -> void:
	if not TEXT.has(id) or not _scene.settings.snapshot().onboarding.enabled or (not repeat and (_shown.has(id) or id in _scene.settings.snapshot().onboarding.seen)):
		return
	if _current != "": return
	_current = id
	_shown[id] = true
	_visible_until = _clock + 12.0
	message_changed.emit("Wick / supplies" if id=="depth" and _scene.chapter!=null and _scene.chapter.active else TEXT[id][0],_body(id))
func complete(id: String) -> void:
	var value: Dictionary = _scene.settings.snapshot().onboarding
	if id not in value.seen:
		value.seen.append(id)
		_scene.settings.set_onboarding(value)
		_scene.settings.save_settings(_scene.settings_path)
	if _current == id:
		_current = ""
		message_changed.emit("","")
func _process(delta: float) -> void:
	if _scene == null or not _scene.submarine.is_physics_processing(): return
	_clock += delta
	if _current != "" and _clock >= _visible_until:
		_current = ""
		message_changed.emit("","")
	if _scene.submarine.global_position.distance_to(_initial_position) > 100.0 and "movement" not in _scene.settings.snapshot().onboarding.seen:
		complete("movement")
		show_hint("sonar")
	if _clock > 15.0 and _scene.station.is_in_range(_scene.submarine.global_position):
		show_hint("station")
	if _scene.chapter!=null and _scene.chapter.active:
		if _clock>30.0: show_hint("depth")
	elif _clock > 65.0: show_hint("torpedo")
	if _scene.submarine.global_position.distance_to(_scene.creature.global_position) < 340.0:
		show_hint("wildlife")
func toggle() -> Error:
	var before: Dictionary = _scene.settings.snapshot().onboarding
	var next: Dictionary = before.duplicate(true)
	next.enabled = not next.enabled
	_scene.settings.set_onboarding(next)
	var result: Error = _scene.settings.save_settings(_scene.settings_path)
	if result != OK: _scene.settings.set_onboarding(before)
	return result
