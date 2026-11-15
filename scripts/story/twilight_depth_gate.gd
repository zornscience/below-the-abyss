class_name TwilightDepthGate
extends CanvasLayer
## Depth-gate presentation: basin depth readout near the gate and the one-time hint.
## Hull failure no longer respawns here: VesselRecoveryFlow recovers the vessel at
## Halcyon in both chapters (supersedes the BTA-059 ascent-tether respawn).
var scene: ShelfPrototype
var _hint_attempted: bool = false
var _near: bool = false
var _depth_cache: float = -1.0
var _rating_cache: float = -1.0
func setup(game: ShelfPrototype) -> void:
	scene = game
	layer = 110
	scene.settings.settings_changed.connect(func() -> void: _hint_attempted = false)
func _process(_delta: float) -> void:
	if scene==null or not scene.journey.active(): return
	if scene.journey.recovery!=null and scene.journey.recovery.pending: return
	var gate: DepthGateProfile = TwilightShelfLayout.DEPTH_GATE
	var near: bool = scene.submarine.global_position.distance_to(gate.approach)<600 or scene.submarine.global_position.distance_to(gate.exit)<600
	var damage: SubmarineDamageSystem = scene.submarine.damage_system
	if near!=_near or damage.depth_m!=_depth_cache or damage.get_maximum_depth_m()!=_rating_cache:
		_near = near
		_depth_cache = damage.depth_m
		_rating_cache = damage.get_maximum_depth_m()
		scene.hud._depth_changed(_depth_cache,_rating_cache)
		if near: (scene.hud.get_node("%DepthValue") as Label).text = "%.0f m / BASIN %.0f m" % [_depth_cache,gate.depth_m]
	if near and not _hint_attempted and scene.submarine.is_physics_processing() and scene.tutorial._current=="":
		_hint_attempted = true
		scene.tutorial.show_hint("twilight-depth")
