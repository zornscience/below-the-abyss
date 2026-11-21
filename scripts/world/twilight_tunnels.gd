class_name TwilightTunnels
extends Node2D
## Optional shortcuts share the existing cut journal. Enabling never resets cuts.
var scene: ShelfPrototype
var gates: Array[DestructibleRock] = []
var vents: Array[ThermalVent] = []
var enabled: bool = false
## Which authored set this node builds. Set before setup(); the Drowned Caves use their own.
var systems: TunnelSetProfile = TwilightTunnelCatalog.DATA
func setup(game: ShelfPrototype) -> void:
	scene = game
	var hull: CapsuleShape2D = (scene.submarine.get_node("CollisionShape2D") as CollisionShape2D).shape as CapsuleShape2D
	if not TwilightTunnelCatalog.is_valid(hull.height,systems,1 if systems!=TwilightTunnelCatalog.DATA else 2):
		push_error("Invalid authored tunnels")
		return
	for profile: TunnelProfile in systems.systems:
		var rock: DestructibleRock = DestructibleRock.new()
		add_child(rock)
		rock.configure(profile.gate_id,profile.world_path(SunlitSurveyData.plug_contour(profile.gate_bounds,profile.seed)),Color("476573"))
		rock.material = scene.chapter.dressing.rocks._fractured
		scene.excavation.register(rock)
		gates.append(rock)
		if profile.vent_id.is_empty(): continue
		var vent: ThermalVent = ThermalVent.new()
		vent.stable_id = profile.vent_id
		vent.position = profile.origin+profile.vent_at
		add_child(vent)
		var result: Error = vent.setup(scene)
		if result!=OK: push_error("Invalid tunnel vent: "+error_string(result))
		vent.damage_applied.connect(scene.hud.show_thermal_damage)
		vents.append(vent)
	scene.saves.checkpoint_restored.connect(reset_session)
	scene.settings.settings_changed.connect(_preferences)
	set_enabled(false)
func set_enabled(value: bool) -> void:
	var changed: bool = enabled!=value
	enabled = value
	visible = value
	for rock: DestructibleRock in gates: rock.collision_layer = 1 if value else 0
	for vent: ThermalVent in vents: vent.enabled = value
	if changed: reset_session()
func reset_session() -> void:
	for vent: ThermalVent in vents: vent.reset_session()
func _preferences() -> void:
	for vent: ThermalVent in vents: vent.refresh_visuals()
func hazard_prompt() -> String:
	for vent: ThermalVent in vents:
		var text: String = vent.prompt(scene.submarine.global_position)
		if not text.is_empty(): return text
	return ""
func unsafe_at(at: Vector2) -> bool:
	for vent: ThermalVent in vents:
		if vent.danger_at(at): return true
	return false
func _physics_process(delta: float) -> void:
	if not enabled or not scene.submarine.is_physics_processing(): return
	for vent: ThermalVent in vents: vent.advance(delta)
